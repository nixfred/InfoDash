// Which tailnet hosts the fleet panel shows. A host matches a list entry by its
// tailscale host name or by its DNS name. Ignored hosts are dropped first, so
// they never take one of the eight places. A host pinned by its DNS name is shown
// under that name.
export type FleetRow = { name: string; dns: string };

export function pickFleet<T extends FleetRow>(rows: T[], pin: string[], ignore: string[], max = 8): T[] {
  const is = (r: T, n: string) => r.name === n || r.dns === n;
  const kept = rows.filter((r) => !ignore.some((n) => is(r, n)));
  const found = new Map<T, T>();
  for (const n of pin) {
    const r = kept.find((x) => is(x, n));
    if (r && !found.has(r)) found.set(r, r.name === n ? r : { ...r, name: n });
  }
  return (found.size ? [...found.values()] : kept).slice(0, max);
}
