# InfoDash

A live system HUD for the [Omarchy](https://omarchy.org) desktop. InfoDash paints your wallpaper and a full dashboard on top of it: CPU, memory, GPU and storage gauges, USB device topology, network and PCIe links, PipeWire routing, tailnet hosts, and the AI coding sessions running on this machine or on any other machine you can ssh to. One keypress summons it over your windows.

![InfoDash, Star Trek skin](docs/infodash-startrek.jpg)

**Colours always follow your Omarchy theme.** Skins change shape, type and gauge style, never colour.

## Features

- **Nine skins**: Star Trek (default), Cyberpunk, Steampunk, Art Deco, 8-bit, Blueprint, Nostromo, Cassette, Diesel. Pick one from the small chip in the header.
- **Drag and snap layout**: hold `CTRL` and drag a panel to move it, drag an edge or corner to resize it. Panels snap to a 48 x 24 grid and push each other out of the way. The layout is saved per monitor.
- **AI sessions panel**: every agent session (Claude Code, Codex and others) with its status, title, model and last message. Point it at another tailnet machine from the host picker. With herdr, clicking a session focuses it there and jumps your focus to the herdr window. A session that is not open in herdr is shown dimmed and is not clickable.
- **Summon overlay**: a fullscreen twin of the dashboard for when windows cover the desktop.
- **Its own text size**: a size control for InfoDash, independent of the system font size.
- **Read-only**: the collector only reads `/proc`, `/sys` and a few status commands.

![All nine skins](docs/infodash-skins.jpg)

## Requirements

- Omarchy (Hyprland with the Lua config, and Quickshell) with the plugin system enabled
- [bun](https://bun.sh) for the collector
- Optional: `tailscale` (fleet panel and remote AI sessions), `nvidia-smi` (NVIDIA GPUs), `pactl` (PipeWire panel), `herdr` (click to focus)

## Install

```sh
git clone https://github.com/nixfred/InfoDash ~/.config/omarchy/plugins/nixfred.infodash
omarchy plugin enable nixfred.infodash
```

While enabled, InfoDash replaces the stock background plugin; disabling it restores the stock one. To update, `git pull` in the plugin directory and restart the shell (`omarchy restart shell`).

## Use

| Action | How |
|---|---|
| Hide the current app behind a clear background with InfoDash (and bring it back) | bind a key to `omarchy-shell shell toggle nixfred.infodash '{}'` |
| Show or hide the InfoDash panels | bind a key to `omarchy-shell infodash toggleDashboard` |
| Move a panel | hold `CTRL`, drag the panel |
| Resize a panel | hold `CTRL`, drag an edge or corner |
| Cancel a drag | `Esc` |
| Reset the layout | `CTRL` + double-click the title |
| Change skin or text size | click the `SKIN` chip in the header |
| Next or previous skin | `omarchy-shell infodash cycleSkin` / `prevSkin` |
| Choose the machine whose AI sessions are shown | the `HOST` chip in the AI SESSIONS panel |

Other commands: `setSkin <id>`, `setFontScale <0.8-1.5>`, `setAiHost <name>`, `aiSessions`, `status`.

## Settings

`~/.config/omarchy/infodash/settings.json` (written by the UI; delete it to start over):

| Key | Meaning |
|---|---|
| `skin` | one of `startrek cyberpunk steampunk deco 8bit blueprint nostromo cassette diesel` |
| `fontScale` | InfoDash text and UI size, 0.8 to 1.5 |
| `aiHost` | tailnet host whose AI sessions are shown, empty for this machine |
| `fleet` | optional list of tailnet host names to pin in the fleet panel (default: the first 8 peers) |
| `snippetStrip` | optional regular expression removed from the start of each last-message snippet, for agents that begin every reply with a banner |

Panel layouts are in `layout.json` in the same folder, one layout per monitor name.

## AI sessions and privacy

The panel scans the chosen machine (`scan.sh`, plain POSIX sh) for herdr agents and agent processes, and reads the last assistant message of each Claude Code session from its transcript under `~/.claude/projects`. A short snippet of it is shown on your desktop and cached under `~/.cache/infodash` (mode 0600) on the scanned machine; entries older than a week are pruned. Remote scans use your normal ssh setup with `BatchMode`, so they never prompt and never store a password. They run with agent, X11 and port forwarding disabled, under a timeout, with the output size capped.

## Development

```sh
bun test           # layout engine, AI-session parsing, window matching, the scan script
```

QML plus a small bun collector (`collector.ts`). `Layout.js` is the grid engine, `Skins.js` the skin registry (one `Skin*.qml` frame per skin), `Ai.js` and `scan.sh` the session scan and parsing. Test changes in a throwaway VM before your desktop; the plugin cannot be verified from unit tests alone.

## License

MIT. Started from the overlay and wallpaper code of [Infomarchy](https://github.com/nixfred/infomarchy).
