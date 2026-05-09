# send-to-sftp

> Right-click any file or folder in your Linux file manager → **Send to SFTP** → pick a host from your `~/.ssh/config` → done.

A tiny, dependency-light utility that brings the macOS-style "Send to…" experience to Linux SFTP/SSH workflows. It plugs into **Nautilus** (GNOME Files), **Nemo** (Cinnamon), **Caja** (MATE), and **Thunar** (XFCE) via their native scripts/custom-actions extension points, then uses `rsync` over SSH and your existing `~/.ssh/config` host aliases — so key auth, jump hosts, ports, and usernames Just Work.

```
┌─────────────────┐      ┌─────────────────────┐      ┌──────────────────────┐
│  Files          │      │  send-to-sftp       │      │  rsync over ssh      │
│  (Nautilus)     │ ───▶ │  GUI picker         │ ───▶ │  via ~/.ssh/config   │
│  right-click    │      │  host + dest path   │      │  key-based auth      │
└─────────────────┘      └─────────────────────┘      └──────────────────────┘
```

## Why

Existing options are either heavy GUI clients (FileZilla, WinSCP-via-Wine) or terminal-only (`sftp`, `lftp`, `rclone`). `send-to-sftp` sits in the middle: **GUI ergonomics where you actually pick the file (the file manager), terminal-grade transport underneath**.

## Features

- 🔌 **Zero-configure host list** — parsed straight from `~/.ssh/config`
- 🔑 **Native SSH key auth** — uses your `IdentityFile`, agent, jump hosts, and ProxyCommand
- 📂 **Files + folders + multi-select** — handles drag-style multi-selection from the file manager
- 🗂 **Remote path picker** — browse the remote filesystem in a small GUI dialog (no need to type `/var/www/...`)
- 🔖 **Recent destinations** — remembers `host:/path` pairs you've used recently
- 🟢 **Live progress** — desktop notification with transfer percentage and speed
- 🧩 **Multiple file managers** — Nautilus, Nemo, Caja, Thunar (one installer)
- 📦 **Single-script install** — no daemons, no Python deps, no Electron, ~600 lines of `bash`

## Quick start

```bash
git clone https://github.com/MMTE/send-to-sftp.git
cd send-to-sftp
./install.sh
```

The installer:
1. Detects your file manager(s) and installs the right-click hook for each one
2. Drops the `send-to-sftp` script into `~/.local/bin`
3. Verifies `rsync`, `ssh`, and `yad` (or `zenity`) are installed and offers to `apt install` what's missing

Then in Files (Nautilus):

> Select files → right-click → **Scripts → Send to SFTP**

Pick a host (autocompleted from `~/.ssh/config`), pick a remote folder, hit OK.

## Example `~/.ssh/config`

```sshconfig
Host prod-web
    HostName 10.0.0.12
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    Port 2222

Host backup
    HostName backup.example.com
    User deploy
    ProxyJump bastion
```

Both `prod-web` and `backup` show up in the picker automatically. Adding new hosts to `~/.ssh/config` makes them appear immediately — no app config to edit.

## Requirements

- Linux with Nautilus, Nemo, Caja, or Thunar
- `bash` ≥ 4, `rsync`, `ssh`
- `yad` (preferred) or `zenity` for dialogs
- `notify-send` (libnotify) for progress notifications

All can be installed via:

```bash
sudo apt install rsync openssh-client yad libnotify-bin
```

## Uninstall

```bash
./install.sh --uninstall
```

## Configuration

`~/.config/send-to-sftp/config` (auto-created on first run):

```ini
# default rsync flags
RSYNC_FLAGS="-az --partial --info=progress2"

# how many recent destinations to remember
RECENT_LIMIT=15

# use yad if available, else zenity
DIALOG_TOOL=auto
```

## Status

Early. See [PLAN.md](./PLAN.md) for the roadmap and milestone breakdown.

## License

MIT — see [LICENSE](./LICENSE).

## Contributing

Issues and PRs welcome. Run the test suite with:

```bash
./tests/run.sh   # uses bats-core
```

Lint:

```bash
shellcheck bin/send-to-sftp install.sh
```
