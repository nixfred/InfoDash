// The active power profile, read the way stock Omarchy 4.5 reads it: one busctl
// call on the net.hadess.PowerProfiles D-Bus service. powerprofilesctl is a
// PyGObject script, so every call started a Python interpreter, and on Python 3.14
// it can SIGSEGV at shutdown (python/cpython#124619).
export const POWER_PROFILE_CMD = ["busctl", "--json=short", "get-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile"];

// busctl prints {"type":"s","data":"performance"}. Empty or malformed text gives "".
export function parseActiveProfile(text: string): string {
  try {
    const d = JSON.parse(text)?.data;
    return typeof d === "string" ? d.trim() : "";
  } catch { return ""; }
}
