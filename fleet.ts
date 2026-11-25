// Which tailnet hosts the fleet panel shows. A host matches a list entry by its
// tailscale host name or by its DNS name. Ignored hosts are dropped first, so
// they never take one of the eight places.
export type FleetRow = { name: string; dns: string };

export function pickFleet<T extends FleetRow>(rows: T[], pin: string[], ignore: string[], max = 8): T[] {
  const is = (r: T, n: string) => r.name === n || r.dns === n;
  const kept = rows.filter((r) => !ignore.some((n) => is(r, n)));
  const pinned = [...new Set(pin.map((n) => kept.find((r) => is(r, n))).filter(Boolean) as T[])];
  return (pinned.length ? pinned : kept).slice(0, max);
}
