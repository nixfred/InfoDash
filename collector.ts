#!/usr/bin/env bun
// infodash collector: one long-running process, one JSON line per tick on stdout.
// Read-only. Every slow source (lsusb-ish sysfs walks, pactl, tailscale, df, lspci)
// refreshes on its own period into a cache; a tick only assembles the cache plus
// the cheap /proc counters, so a slow tool can never stall the stream.
//
//   bun collector.ts [--interval 2000] [--fleet host1,host2] [--ignore host3] [--once]
//   --fleet pins tailnet hosts to show (by tailscale host or DNS name); without it the first 8 peers are shown.
//   --ignore names tailnet hosts that are never shown, pinned or not.

import { readFileSync, readdirSync, readlinkSync, realpathSync } from "node:fs";
import { hostname, homedir } from "node:os";
import { rename } from "node:fs/promises";
import { pickFleet } from "./fleet.ts";
import { POWER_PROFILE_CMD, parseActiveProfile } from "./power.ts";

const argv = process.argv.slice(2);
const opt = (name: string, dflt: string) => { const i = argv.indexOf(name); return i >= 0 && argv[i + 1] ? argv[i + 1] : dflt; };
const INTERVAL = Math.max(500, Number(opt("--interval", "2000")) || 2000);
const names = (s: string) => s.split(",").map((x) => x.trim().toLowerCase()).filter(Boolean);
const FLEET = names(opt("--fleet", ""));
const IGNORE = names(opt("--ignore", ""));
const ONCE = argv.includes("--once");
const HISTORY = 45;

// ---------------------------------------------------------------- helpers
const rd = (p: string): string => { try { return readFileSync(p, "utf8").trim(); } catch { return ""; } };
const ls = (p: string): string[] => { try { return readdirSync(p); } catch { return []; } };
const num = (s: string): number | null => { const n = parseFloat(s); return Number.isFinite(n) ? n : null; };
const rl = (p: string): string => { try { return realpathSync(p); } catch { return ""; } };
const base = (p: string) => p.split("/").filter(Boolean).pop() || "";

// Runs a command. Resolves to its stdout, or null if it could not start, failed, or took longer than `ms`
// (a process stuck in uninterruptible I/O never closes its pipe, so the wait itself is raced against a timer).
async function runRaw(cmd: string[], ms = 3000, okCodes: number[] = [0]): Promise<string | null> {
  let p: any;
  try {
    p = Bun.spawn(cmd, { stdout: "pipe", stderr: "ignore", stdin: "ignore" });
    let timer: any;
    const timeout = new Promise<null>((res) => { timer = setTimeout(() => { try { p.kill(9); } catch {} res(null); }, ms); });
    const work = (async () => { const out = await new Response(p.stdout).text(); const code = await p.exited; return okCodes.includes(code) ? out : null; })();
    const r = await Promise.race([work, timeout]);
    clearTimeout(timer);
    return r;
  } catch { try { p?.kill(9); } catch {} return null; }
}
async function run(cmd: string[], ms = 3000): Promise<string> { return (await runRaw(cmd, ms)) ?? ""; }
const json = (s: string): any => { try { return JSON.parse(s); } catch { return null; } };

// A cached source: refresh() runs at most once per periodMs, never overlapping.
function cached<T>(periodMs: number, initial: T, refresh: () => Promise<T>) {
  const c = { value: initial, at: 0, busy: false };
  return () => {
    if (!c.busy && Date.now() - c.at >= periodMs) {
      c.busy = true; c.at = Date.now();
      refresh().then((v) => { c.value = v; }).catch(() => {}).finally(() => { c.busy = false; });
    }
    return c.value;
  };
}

// ---------------------------------------------------------------- hwmon
type Hwmon = { name: string; dir: string };
function hwmons(): Hwmon[] {
  return ls("/sys/class/hwmon").map((d) => ({ dir: `/sys/class/hwmon/${d}`, name: rd(`/sys/class/hwmon/${d}/name`) }));
}
const milli = (p: string): number | null => { const n = num(rd(p)); return n === null ? null : n / 1000; };

// ---------------------------------------------------------------- names (lspci)
type PciName = { cls: string; name: string; vendor: string };
let pciMap = new Map<string, PciName>(), pciAt = 0, pciP: Promise<Map<string, PciName>> | null = null;
const pciNames = () => pciMap;                                  // sync read of whatever is cached
function loadPciNames(): Promise<Map<string, PciName>> {         // awaitable: waits for the first lspci
  if (pciP && Date.now() - pciAt < 300000) return pciP;
  pciAt = Date.now();
  pciP = (async () => {
    const m = new Map<string, PciName>();
    for (const line of (await run(["lspci", "-mm", "-D"], 4000)).split("\n")) {
      const r = line.match(/^(\S+)\s+"([^"]*)"\s+"([^"]*)"\s+"([^"]*)"/);
      if (!r) continue;
      const dev = r[4].match(/\[([^\]]+)\]\s*$/);              // "Navi 48 [Radeon RX 9070]" -> Radeon RX 9070
      const vendor = r[3].replace(/\[.*?\]/g, "").replace(/\b(Corporation|Inc\.?|Co\.?,? Ltd\.?|Advanced Micro Devices,?|Technology|Technologies)\b/gi, "").replace(/[,.]/g, "").replace(/\s+/g, " ").trim().split(" ")[0] || "";
      m.set(r[1], { cls: r[2], name: (dev ? dev[1] : r[4]).trim(), vendor });
    }
    if (m.size) pciMap = m;
    return pciMap;
  })();
  return pciP;
}
loadPciNames();

// ---------------------------------------------------------------- cpu
let prevCpu: { total: number; idle: number }[] = [];
function cpu(hist: number[]) {
  const stat = rd("/proc/stat").split("\n").filter((l) => /^cpu\d*\s/.test(l));
  const cur = stat.map((l) => { const f = l.split(/\s+/).slice(1).map(Number); const idle = f[3] + (f[4] || 0); return { total: f.slice(0, 8).reduce((a, b) => a + b, 0), idle }; });
  const busy = cur.map((c, i) => { const p = prevCpu[i]; if (!p) return 0; const dt = c.total - p.total; return dt > 0 ? Math.max(0, Math.min(100, Math.round(100 * (1 - (c.idle - p.idle) / dt)))) : 0; });
  prevCpu = cur;
  const info = rd("/proc/cpuinfo");
  const model = (info.match(/^model name\s*:\s*(.+)$/m) || [, ""])[1].replace(/\(R\)|\(TM\)|CPU|Processor|\s+\d+-Core/gi, "").replace(/\s+/g, " ").trim();
  const cpus = ls("/sys/devices/system/cpu").filter((d) => /^cpu\d+$/.test(d)).sort((a, b) => Number(a.slice(3)) - Number(b.slice(3)));
  const mhz = cpus.map((c) => (num(rd(`/sys/devices/system/cpu/${c}/cpufreq/scaling_cur_freq`)) ?? 0) / 1000).filter((x) => x > 0);
  let tempC: number | null = null, tjmax = 95;
  for (const h of hwmons()) {
    if (!/^(k10temp|coretemp|zenpower|cpu_thermal)$/.test(h.name)) continue;
    for (const f of ls(h.dir).filter((n) => /^temp\d+_label$/.test(n))) {
      const lbl = rd(`${h.dir}/${f}`);
      if (/Tctl|Package|Tdie/.test(lbl)) { tempC = milli(`${h.dir}/${f.replace("_label", "_input")}`); const c = milli(`${h.dir}/${f.replace("_label", "_crit")}`); if (c) tjmax = c; }
    }
    if (tempC === null) tempC = milli(`${h.dir}/temp1_input`);
    if (tempC !== null) break;
  }
  const t = busy[0] ?? 0;
  // core ids repeat across sockets, so a core is a (socket, core id) pair
  const physical = new Set(info.split("\n\n").map((b) => { const c = b.match(/^core id\s*:\s*(\d+)$/m); return c ? (b.match(/^physical id\s*:\s*(\d+)$/m)?.[1] ?? "0") + ":" + c[1] : ""; }).filter(Boolean)).size;
  return {
    model, threads: Math.max(0, cur.length - 1), cores: physical || Math.max(0, cur.length - 1),
    busyPct: t, avgMHz: mhz.length ? Math.round(mhz.reduce((a, b) => a + b, 0) / mhz.length) : null,
    coreBusy: busy.slice(1), tempC, tjmax: Math.round(tjmax),
  };
}

// ---------------------------------------------------------------- memory
function mem() {
  const m: Record<string, number> = {};
  for (const l of rd("/proc/meminfo").split("\n")) { const r = l.match(/^(\w+):\s+(\d+)/); if (r) m[r[1]] = Number(r[2]); }
  const total = m.MemTotal || 0, avail = m.MemAvailable ?? m.MemFree ?? 0;
  const dimm = hwmons().filter((h) => /^(spd5118|jc42)/.test(h.name)).map((h) => milli(`${h.dir}/temp1_input`)).filter((x): x is number => x !== null);
  return { totalGB: total / 1048576, usedGB: (total - avail) / 1048576, availGB: avail / 1048576, usedPct: total ? Math.round(100 * (total - avail) / total) : 0,
    swapUsedGB: ((m.SwapTotal || 0) - (m.SwapFree || 0)) / 1048576, swapTotalGB: (m.SwapTotal || 0) / 1048576, dimmC: dimm.map(Math.round) };
}

// ---------------------------------------------------------------- storage
const storage = cached(10000, { mounts: [] as any[], nvme: [] as any[] }, async () => {
  const out = await run(["df", "-lB1", "--output=source,fstype,size,used,avail,target"], 3000);
  const seen = new Set<string>(), mounts: any[] = [];
  for (const l of out.split("\n").slice(1)) {
    const f = l.trim().split(/\s+/);
    if (f.length < 6 || !f[0].startsWith("/dev/") || /^(squashfs|vfat|iso9660)$/.test(f[1]) || seen.has(f[0])) continue;
    const target = f.slice(5).join(" ");
    if (/^\/(boot|efi)/.test(target)) continue;
    seen.add(f[0]);
    const size = Number(f[2]), used = Number(f[3]), avail = Number(f[4]);
    if (size > 1e9 && used + avail > 0) mounts.push({ mount: target, usedGB: used / 1e9, totalGB: size / 1e9, pct: Math.round(100 * used / (used + avail)) });
  }
  const nvme = hwmons().filter((h) => h.name === "nvme").map((h) => ({ name: base(rl(`${h.dir}/device`)) || "nvme", tempC: milli(`${h.dir}/temp1_input`) }));
  return { mounts: mounts.slice(0, 4), nvme };
});

// ---------------------------------------------------------------- gpu
const nvidia = cached(3000, [] as any[], async () => {
  const out = await run(["nvidia-smi", "--query-gpu=pci.bus_id,name,temperature.gpu,utilization.gpu,power.draw,clocks.sm,memory.used,memory.total", "--format=csv,noheader,nounits"], 3000);
  return out.split("\n").filter(Boolean).map((l) => l.split(",").map((s) => s.trim())).filter((f) => f.length >= 8).map((f) => { return { slot: f[0].toLowerCase().slice(-12), name: f[1], tempC: num(f[2]), loadPct: num(f[3]), powerW: num(f[4]), clockMHz: num(f[5]), vramUsedMB: num(f[6]), vramTotalMB: num(f[7]) }; });
});
function gpus() {
  const names = pciNames(), nv = nvidia(), out: any[] = [];
  for (const c of ls("/sys/class/drm").filter((d) => /^card\d+$/.test(d))) {
    const dev = `/sys/class/drm/${c}/device`;
    if (!rd(`${dev}/class`).startsWith("0x03")) continue;
    const slot = base(rl(dev)), vendor = rd(`${dev}/vendor`), n = nv.find((x) => x.slot === slot);
    const hw = ls(`${dev}/hwmon`)[0], hd = hw ? `${dev}/hwmon/${hw}` : "";
    const g: any = { slot, vendor: vendor === "0x10de" ? "nvidia" : vendor === "0x1002" ? "amd" : vendor === "0x8086" ? "intel" : "other",
      name: n?.name || names.get(slot)?.name || slot, primary: rd(`${dev}/boot_vga`) === "1", tempC: null, loadPct: null, powerW: null, clockMHz: null, vramUsedMB: null, vramTotalMB: null, note: "" };
    if (n) Object.assign(g, n, { slot, vendor: "nvidia", primary: g.primary });
    else {
      g.tempC = hd ? milli(`${hd}/temp1_input`) : null;
      const pw = hd ? num(rd(`${hd}/power1_average`) || rd(`${hd}/power1_input`)) : null; g.powerW = pw === null ? null : pw / 1e6;
      const fq = hd ? num(rd(`${hd}/freq1_input`)) : null;
      g.clockMHz = fq !== null ? fq / 1e6 : num(rd(`/sys/class/drm/${c}/gt_cur_freq_mhz`));
      g.loadPct = num(rd(`${dev}/gpu_busy_percent`));
      const vu = num(rd(`${dev}/mem_info_vram_used`)), vt = num(rd(`${dev}/mem_info_vram_total`));
      if (vu !== null && vt) { g.vramUsedMB = vu / 1048576; g.vramTotalMB = vt / 1048576; }
    }
    if (g.tempC === null && g.loadPct === null && g.powerW === null) g.note = "sensors unavailable";
    out.push(g);
  }
  return out.sort((a, b) => Number(b.primary) - Number(a.primary));
}

// ---------------------------------------------------------------- network
let prevNet: Record<string, { rx: number; tx: number }> = {}, prevNetAt = Date.now();
const addrs = cached<Record<string, string>>(5000, {}, async () => {
  const j = json(await run(["ip", "-j", "-4", "addr"], 2000)) || [];
  const o: Record<string, string> = {};
  for (const i of j) { const a = (i.addr_info || [])[0]; if (a) o[i.ifname] = `${a.local}/${a.prefixlen}`; }
  return o;
});
function net() {
  const now = Date.now(), dt = Math.max(0.2, (now - prevNetAt) / 1000); prevNetAt = now;
  const cur: Record<string, { rx: number; tx: number }> = {}, ifaces: any[] = [], ad = addrs();
  let rxT = 0, txT = 0, rxR = 0, txR = 0;
  for (const l of rd("/proc/net/dev").split("\n").slice(2)) {
    const m = l.match(/^\s*([^:]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/); if (!m) continue;
    const name = m[1]; if (name === "lo" || /^(veth|docker|br-|virbr)/.test(name)) continue;
    cur[name] = { rx: Number(m[2]), tx: Number(m[3]) };
    const p = prevNet[name], rate = p ? { rx: Math.max(0, (cur[name].rx - p.rx) / dt), tx: Math.max(0, (cur[name].tx - p.tx) / dt) } : { rx: 0, tx: 0 };
    const op = rd(`/sys/class/net/${name}/operstate`), addr = ad[name] || "";
    const state = op === "up" || (op === "unknown" && addr) ? "UP" : "DOWN";
    ifaces.push({ name, state, addr: addr || (state === "UP" ? "no address" : "no carrier"), rxRate: rate.rx, txRate: rate.tx });
    rxT += cur[name].rx; txT += cur[name].tx; rxR += rate.rx; txR += rate.tx;
  }
  prevNet = cur;
  ifaces.sort((a, b) => (a.state === b.state ? 0 : a.state === "UP" ? -1 : 1));
  return { ifaces: ifaces.slice(0, 5), rxBytes: rxT, txBytes: txT, rxRate: rxR, txRate: txR };
}

// ---------------------------------------------------------------- pcie
const pcie = cached(60000, [] as any[], async () => {
  const names = await loadPciNames(), out: any[] = [];
  for (const d of ls("/sys/bus/pci/devices")) {
    const p = `/sys/bus/pci/devices/${d}`, w = num(rd(`${p}/current_link_width`)), mx = num(rd(`${p}/max_link_width`));
    if (w === null || mx === null || w < 1 || mx > 32 || rd(`${p}/class`).startsWith("0x06")) continue;   // skip bridges and integrated (width 0/255) links
    out.push({ slot: d, name: names.get(d)?.name || d, speed: rd(`${p}/current_link_speed`).replace(/\s*PCIe/, ""), width: w, maxWidth: mx });
  }
  return out.sort((a, b) => b.maxWidth - a.maxWidth).slice(0, 10);
});

// ---------------------------------------------------------------- usb
const usb = cached(8000, { controllers: [] as any[] }, async () => {
  const names = await loadPciNames(), root = "/sys/bus/usb/devices", all = ls(root).filter((d) => !d.includes(":"));
  const speedClass = (mb: number) => mb >= 10000 ? "SS+" : mb >= 5000 ? "SS" : mb >= 480 ? "HS" : mb >= 12 ? "FS" : "LS";
  const ctl: any[] = [];
  for (const r of all.filter((d) => d.startsWith("usb")).sort()) {
    const bus = Number(rd(`${root}/${r}/busnum`)), pci = base(rl(`${root}/${r}/..`));
    const letter = String.fromCharCode(65 + ctl.length);
    const devices = all.filter((d) => !d.startsWith("usb") && d.startsWith(`${bus}-`)).map((d) => {
      const p = `${root}/${d}`, mb = num(rd(`${p}/speed`)) ?? 0, hub = rd(`${p}/bDeviceClass`) === "09";
      return { id: `DEV-${Number(rd(`${p}/devnum`))}`, path: d, depth: d.split(".").length, vidpid: `${rd(`${p}/idVendor`)}:${rd(`${p}/idProduct`)}`,
        speed: speedClass(mb), name: rd(`${p}/product`) || rd(`${p}/manufacturer`) || `${rd(`${p}/idVendor`)}:${rd(`${p}/idProduct`)}`,
        hub, meta: hub ? `${num(rd(`${p}/maxchild`)) ?? 0} DN` : `${num(rd(`${p}/bNumInterfaces`)) ?? 1} IF` };
    }).sort((a, b) => a.path.localeCompare(b.path, undefined, { numeric: true }));
    const pn = names.get(pci); const cname = pn ? (pn.name.toLowerCase().includes(pn.vendor.toLowerCase()) ? pn.name : `${pn.vendor} ${pn.name}`) : rd(`${root}/${r}/product`) || "USB CONTROLLER";
    ctl.push({ id: `XHC-${letter}`, pci, name: cname,
      bus, speed: speedClass(num(rd(`${root}/${r}/speed`)) ?? 0), devices });
  }
  return { controllers: ctl.filter((c) => c.devices.length) };
});

// ---------------------------------------------------------------- audio (pactl)
const audio = cached(5000, { sinks: [] as any[], sources: [] as any[], monitors: 0, apps: 0, recorders: 0, defaultSink: "", defaultSource: "" }, async () => {
  const [s, so, si, sp, ds, dsrc] = await Promise.all([
    run(["pactl", "-f", "json", "list", "sinks"]), run(["pactl", "-f", "json", "list", "sources"]),
    run(["pactl", "-f", "json", "list", "sink-inputs"]), run(["pactl", "-f", "json", "list", "source-outputs"]),
    run(["pactl", "get-default-sink"]), run(["pactl", "get-default-source"]),
  ]);
  const shape = (x: any) => { const sp = String(x.sample_specification || "").split(" "); const pr = x.properties || {};
    return { id: x.index, node: x.description || x.name, bus: pr["device.bus"] || "virtual", fmt: sp[0] || "", ch: (sp[1] || "").replace("ch", ""), rate: sp[2] ? `${Math.round(parseInt(sp[2]) / 1000)}k` : "", state: String(x.state || "").toUpperCase() }; };
  const dSink = ds.trim(), dSrc = dsrc.trim();
  const rank = (st: string) => (st === "RUNNING" ? 0 : st === "IDLE" ? 1 : 2);
  const order = (a: any, b: any) => Number(b.isDefault) - Number(a.isDefault) || rank(a.state) - rank(b.state);
  const sinks = (json(s) || []).map((x: any) => ({ ...shape(x), isDefault: x.name === dSink })).sort(order), allSrc = json(so) || [];
  return { sinks, sources: allSrc.filter((x: any) => !String(x.name).endsWith(".monitor")).map((x: any) => ({ ...shape(x), isDefault: x.name === dSrc })).sort(order), monitors: allSrc.filter((x: any) => String(x.name).endsWith(".monitor")).length,
    apps: (json(si) || []).length, recorders: (json(sp) || []).length, defaultSink: ds.trim(), defaultSource: dsrc.trim() };
});

// ---------------------------------------------------------------- fleet (tailscale)
const fleet = cached(15000, [] as any[], async () => {
  const j = json(await run(["tailscale", "status", "--json"], 4000)); if (!j) return [];
  const peers = [j.Self, ...Object.values(j.Peer || {})].filter(Boolean) as any[];
  const rows = peers.map((p) => ({ name: String(p.HostName || "").toLowerCase(), dns: String(p.DNSName || "").split(".")[0].toLowerCase(), online: p === j.Self ? true : p.Online === true, os: p.OS || "", ip: (p.TailscaleIPs || [])[0] || "", self: p === j.Self, lastSeen: p.LastSeen || "" }));
  return pickFleet(rows, FLEET, IGNORE);
});

// ---------------------------------------------------------------- ai agents (/proc)
const AGENTS = /^(claude|codex|gemini|grok|opencode|aider|cursor-agent|hermes)$/;
const ai = cached(4000, { sessions: [] as any[] }, async () => {
  const up = num(rd("/proc/uptime").split(" ")[0]) ?? 0, out: any[] = [];
  for (const pid of ls("/proc").filter((d) => /^\d+$/.test(d))) {
    const comm = rd(`/proc/${pid}/comm`); if (!AGENTS.test(comm)) continue;
    const cwd = (() => { try { return readlinkSync(`/proc/${pid}/cwd`); } catch { return ""; } })();
    const st = rd(`/proc/${pid}/stat`).replace(/^.*\)\s+/, "").split(" "), start = Number(st[19]) / 100;
    out.push({ provider: comm, pid: Number(pid), cwd, project: base(cwd) || "?", ageSec: Math.max(0, Math.round(up - start)) });
  }
  return { sessions: out.sort((a, b) => a.ageSec - b.ageSec).slice(0, 8) };
});

// ---------------------------------------------------------------- ledger
const ledger = cached(5000, { theme: "", powerProfile: "", nightlight: null as boolean | null }, async () => {
  const [th, pp, nl] = await Promise.all([run(["omarchy-theme-current"], 2000), run(POWER_PROFILE_CMD, 2000), run(["omarchy-toggle-nightlight", "--status"], 2000)]);
  return { theme: th.trim() || rd(`${homedir()}/.local/state/omarchy/current/theme.name`), powerProfile: parseActiveProfile(pp), nightlight: (json(nl) || {}).enabled ?? null };
});
const updates = cached(900000, { count: null as number | null }, async () => {
  const out = await runRaw(["checkupdates", "--nocolor"], 60000, [0, 2]);   // exit 2 = nothing to update; anything else (or a timeout) = unknown
  return { count: out === null ? null : out.split("\n").filter(Boolean).length };
});

// ---------------------------------------------------------------- tick
const hist = { cpuTemp: [] as number[], memGB: [] as number[], rootPct: [] as number[] };
const push = (a: number[], v: number | null | undefined) => { if (v === null || v === undefined) return; a.push(Math.round(v * 10) / 10); if (a.length > HISTORY) a.shift(); };

function snapshot() {
  const c = cpu(hist.cpuTemp), m = mem(), st = storage();
  push(hist.cpuTemp, c.tempC); push(hist.memGB, m.usedGB);
  push(hist.rootPct, (st.mounts.find((x: any) => x.mount === "/") || st.mounts[0] || {}).pct);
  return {
    v: 1, ts: Date.now(), host: hostname().split(".")[0], uptimeSec: Math.round(num(rd("/proc/uptime").split(" ")[0]) ?? 0),
    cpu: c, mem: m, gpus: gpus(), storage: st, net: net(), pcie: pcie(), usb: usb(), audio: audio(), fleet: fleet(), ai: ai(),
    ledger: { ...ledger(), updates: updates().count }, hist,
  };
}

snapshot();                                  // prime the counter baselines
if (ONCE) { await Bun.sleep(1500); console.log(JSON.stringify(snapshot())); process.exit(0); }

// Latest snapshot also goes to a private runtime file so a freshly summoned overlay can paint real data at once.
// Only under XDG_RUNTIME_DIR (a per-user 0700 directory); never a predictable name in /tmp.
const RUNDIR = process.env.XDG_RUNTIME_DIR || "";
const SEED = RUNDIR ? RUNDIR + "/infodash-snap.json" : "";
const PPID0 = process.ppid;

// This process must not outlive the shell that started it: leave when stdout closes or the parent changes.
process.stdout.on("error", () => process.exit(0));
let tickBusy = false;
function tick() {
  if (process.ppid !== PPID0 || process.ppid === 1) process.exit(0);
  if (tickBusy) return;
  tickBusy = true;
  try {
    const line = JSON.stringify(snapshot());
    process.stdout.write(line + "\n");
    if (SEED) Bun.write(SEED + ".tmp." + process.pid, line, { mode: 0o600 }).then(() => rename(SEED + ".tmp." + process.pid, SEED)).catch(() => {});
  } catch (e) { console.error(String(e)); }
  tickBusy = false;
}
setTimeout(tick, 600);                       // first frame early (cpu needs two samples), then on the interval
setInterval(tick, INTERVAL);
