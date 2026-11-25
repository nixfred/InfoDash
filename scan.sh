#!/bin/sh
# InfoDash AI-session scan. Run locally (sh scan.sh) or over ssh (the plugin pipes it to `sh`).
# Prints sections: ##NOW ##AGENTS ##WS ##PROC ##SNIP, which Ai.js turns into rows.
umask 077
H=$HOME; [ -n "$H" ] || H=~
T=; command -v timeout >/dev/null 2>&1 && T="timeout 4"
echo '##NOW'; date +%s
echo '##AGENTS'; A=$($T herdr agent list 2>/dev/null); printf '%s\n' "$A"
echo '##WS'; $T herdr workspace list 2>/dev/null; echo
echo '##PROC'
if [ -d /proc/1 ]; then
  for d in /proc/[0-9]*; do
    read -r c 2>/dev/null < $d/comm || continue
    case "$c" in claude|codex|gemini|grok|opencode|aider|cursor-agent|hermes)
      pid=${d##*/}
      printf '%s\t%s\t%s\t%s\n' "$pid" "$c" "$(ps -o etimes= -p $pid 2>/dev/null | tr -d ' ')" "$(readlink $d/cwd 2>/dev/null)";;
    esac
  done
else
  ps -axo pid=,comm=,etime= | awk '{ n = split($2, a, "/"); c = a[n]; if (c ~ /^(claude|codex|gemini|grok|opencode|aider|cursor-agent|hermes)$/) printf "%s\t%s\t%s\t\n", $1, c, $3 }'
fi
echo '##SNIP'
C=$H/.cache/infodash; mkdir -p "$C" 2>/dev/null; find "$C" -type f -mtime +7 -delete 2>/dev/null
for id in $(printf '%s' "$A" | grep -o '"value":"[0-9a-f-]*"' | cut -d'"' -f4); do
  f=$(ls $H/.claude/projects/*/$id.jsonl 2>/dev/null | head -1); [ -n "$f" ] || continue
  mt=$(stat -c %Y "$f" 2>/dev/null); [ -n "$mt" ] || mt=$(stat -f %m "$f" 2>/dev/null)
  if [ -f "$C/$id" ] && [ "$(cut -f2 "$C/$id")" = "$mt" ]; then cat "$C/$id"; continue; fi
  l=$(tail -c 2000000 "$f" | grep '"role":"assistant"' | grep '"type":"text"' | tail -1)
  md=$(printf '%s' "$l" | sed -nE 's/.*"model":"([^"]*)".*/\1/p' | head -1)
  tx=$(printf '%s' "$l" | sed -nE 's/.*"type":"text","text":"(([^"\\]|\\.)*)".*/\1/p' | head -1 | cut -c1-300)
  printf '%s\t%s\t%s\t%s\n' "$id" "$mt" "$md" "$tx" | tee "$C/$id"
done
