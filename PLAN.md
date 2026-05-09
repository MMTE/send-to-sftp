# send-to-sftp — Implementation Plan

A bash-first, dependency-light right-click "Send to SFTP" integration for Linux file managers, built around `~/.ssh/config` and `rsync`.

## Goals

1. **Zero friction** for users already using SSH key auth and `~/.ssh/config`.
2. **Native feel** in each supported file manager (Nautilus, Nemo, Caja, Thunar).
3. **One install script**, no runtime daemons, no language runtime beyond bash.
4. **Open source from day 1** under MIT, with CI, tests, and a release flow.

## Non-Goals (v1)

- No password-only auth UI (rely on SSH agent / keys; document `sshpass` workaround)
- No Windows/macOS support
- No Electron/Qt GUI; only `yad`/`zenity` dialogs
- No remote-side daemons; we just call `rsync`/`ssh`

## Architecture

```
~/.local/bin/send-to-sftp                       ← main bash CLI/GUI
~/.local/share/nautilus/scripts/Send to SFTP    ← thin wrapper for Nautilus
~/.local/share/nemo/scripts/Send to SFTP        ← thin wrapper for Nemo
~/.config/caja/scripts/Send to SFTP             ← thin wrapper for Caja
~/.config/Thunar/uca.xml                        ← Thunar custom action entry
~/.config/send-to-sftp/config                   ← user config
~/.config/send-to-sftp/recent                   ← recent destinations
~/.local/share/send-to-sftp/                    ← bundled libs (parse_ssh.sh, ui.sh, transport.sh)
```

The wrappers do nothing but `exec ~/.local/bin/send-to-sftp "$@"`. All logic lives in the main script + sourced libs in `~/.local/share/send-to-sftp/`.

## Module layout (in repo)

```
send-to-sftp/
├── bin/
│   └── send-to-sftp                ← entrypoint
├── lib/
│   ├── parse_ssh.sh                ← parse ~/.ssh/config → host list
│   ├── remote_browse.sh            ← list remote dirs over ssh for picker
│   ├── transport.sh                ← rsync wrapper + progress parsing
│   ├── ui.sh                       ← yad/zenity abstraction
│   ├── recent.sh                   ← recent destinations store
│   └── notify.sh                   ← libnotify wrapper
├── integrations/
│   ├── nautilus/Send to SFTP       ← wrapper script
│   ├── nemo/Send to SFTP
│   ├── caja/Send to SFTP
│   └── thunar/uca.xml.snippet
├── tests/
│   ├── run.sh                      ← bats-core runner
│   ├── parse_ssh.bats
│   ├── recent.bats
│   └── fixtures/
│       └── ssh_config_sample
├── install.sh                      ← installer/uninstaller
├── Makefile                        ← lint, test, install, package
├── .github/workflows/
│   └── ci.yml                      ← shellcheck + bats on push
├── README.md
├── PLAN.md
├── CHANGELOG.md
├── LICENSE                         ← MIT
└── CONTRIBUTING.md
```

## Phased Build

Each phase = one git commit. Phases are sequential except where marked **‖** (parallelizable).

### Phase 1 — Repo skeleton & licensing
- Create directory tree above (empty placeholder files where needed)
- `LICENSE` (MIT, holder: MMTE)
- `.gitignore` (bash project: `*.swp`, `*.bak`, `tests/tmp/`, `dist/`)
- `CHANGELOG.md` with `## [Unreleased]` header
- `CONTRIBUTING.md` (how to run tests, code style, commit conventions)
- `Makefile` targets: `lint`, `test`, `install`, `uninstall`, `package`

### Phase 2 — `lib/parse_ssh.sh`
- Parse `~/.ssh/config` (and `Include` directives) into a list of `Host` aliases
- Skip wildcards (`Host *`, `Host *.example.com`)
- Resolve effective `User`, `HostName`, `Port`, `IdentityFile` per host (via `ssh -G <host>` for accuracy)
- Provide `list_hosts` and `host_info <alias>` functions
- Unit tests in `tests/parse_ssh.bats` against `tests/fixtures/ssh_config_sample`

### Phase 3 — `lib/ui.sh`
- Abstract over `yad` and `zenity`
- Functions: `ui_pick_host <hosts...>`, `ui_pick_path <host> <start_dir>`, `ui_confirm <msg>`, `ui_error <msg>`, `ui_progress <pipe>`
- Auto-detect tool at source time; honor `DIALOG_TOOL` env

### Phase 4 — `lib/remote_browse.sh`
- Given a host alias and a starting path, run `ssh <alias> 'ls -1ap <path>'` and return entries
- Used by `ui_pick_path` to render a "browse remote folder" dialog with up/down navigation
- Cache results per host for the session (avoid hammering ssh)

### Phase 5 — `lib/transport.sh`
- `transport_send <host> <remote_dir> <local_path...>`
- Spawns `rsync -az --partial --info=progress2 -e ssh "$@" "$host:$remote_dir/"`
- Pipes progress to a coproc that emits `percent\nspeed` lines for `ui_progress`
- Returns rsync exit code; on failure, surface stderr in `ui_error`

### Phase 6 — `lib/recent.sh` ‖ Phase 5
- Append-only `~/.config/send-to-sftp/recent` (one `host:/path` per line)
- `recent_add`, `recent_list` (deduped, newest first, capped at `RECENT_LIMIT`)

### Phase 7 — `lib/notify.sh` ‖ Phase 5
- Wrap `notify-send` with app name, icon, replace-id (so progress notifications update in place)
- Fallback to `echo` if libnotify missing

### Phase 8 — `bin/send-to-sftp` (the entrypoint)
- Argv: list of local file/dir paths (passed by file-manager wrapper)
- Flow:
  1. Validate at least one local path
  2. Source libs from `$XDG_DATA_HOME/send-to-sftp/`
  3. Load config from `$XDG_CONFIG_HOME/send-to-sftp/config` (create with defaults if missing)
  4. `parse_ssh.list_hosts` + `recent.recent_list` → merged picker
  5. `ui_pick_host` → host alias
  6. `ui_pick_path` (start at `~` of the remote user) → remote dir
  7. `transport_send` with progress UI
  8. On success: `recent_add`, `notify "Uploaded N files to host:path"`
  9. On failure: `ui_error` with rsync stderr tail

### Phase 9 — File-manager integrations
- `integrations/nautilus/Send to SFTP` — reads `NAUTILUS_SCRIPT_SELECTED_FILE_PATHS` (newline-separated), execs main script
- `integrations/nemo/Send to SFTP` — same env var name (`NEMO_SCRIPT_SELECTED_FILE_PATHS`)
- `integrations/caja/Send to SFTP` — `CAJA_SCRIPT_SELECTED_FILE_PATHS`
- `integrations/thunar/uca.xml.snippet` — XML fragment with `%F` for selected files; merge into existing `~/.config/Thunar/uca.xml` carefully (don't clobber other custom actions)

### Phase 10 — `install.sh`
- Detects which file managers are installed (`command -v nautilus`, etc.)
- Copies main script to `~/.local/bin/send-to-sftp` (chmod +x)
- Copies libs to `~/.local/share/send-to-sftp/`
- Installs each file-manager wrapper into the correct location
- For Thunar: parses existing `uca.xml`, inserts our `<action>` if not already present (idempotent)
- Verifies dependencies (`rsync`, `ssh`, `yad` || `zenity`, `notify-send`); prints `apt install` line for missing
- `--uninstall` flag reverses everything (and removes the Thunar `<action>` by `unique-id`)
- `--user` (default) vs `--system` (writes to `/usr/local/bin` and `/usr/share/<fm>/...`) flags
- Restarts/reloads file managers where required (`nautilus -q`, `nemo --quit`, `thunar -q`)

### Phase 11 — Tests
- `tests/run.sh` runs all `*.bats` files via bats-core (vendored as submodule or `apt install bats`)
- Coverage: `parse_ssh.sh`, `recent.sh`, install dry-run
- Mock `ssh` and `rsync` with `tests/bin/` shims on `PATH`

### Phase 12 — CI
- `.github/workflows/ci.yml`:
  - Job `lint`: `shellcheck` over all `.sh` and `bin/send-to-sftp`
  - Job `test`: install bats, run `make test`
  - Matrix: ubuntu-22.04, ubuntu-24.04
- Badge in README

### Phase 13 — Packaging & release docs
- `Makefile package` target → `dist/send-to-sftp-<version>.tar.gz`
- `CHANGELOG.md` populated with v0.1.0 entry
- Tag `v0.1.0` and create GitHub release via `gh release create` (manual step, documented in CONTRIBUTING)
- README install instructions updated to reference release tarball as alternative to git clone

## Constraints for the orchestrator

- **No external runtime deps** beyond bash, coreutils, ssh, rsync, yad/zenity, libnotify
- **Bash 4 features OK**, but quote everything; pass `shellcheck -x`
- **Idempotent install**: running `install.sh` twice must not duplicate Thunar actions or break wrappers
- **Don't touch `~/.ssh/config`** — read-only
- **Respect XDG dirs** (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`); fall back to `~/.config` and `~/.local/share`
- **One commit per phase**, conventional commit style (`feat:`, `chore:`, `test:`, `ci:`, `docs:`)
- **Do not** add Python, Node, Go, or any compiled component
- **Do not** rewrite the architecture or split into more modules than listed here
- Final phase must run `make lint` and `make test`; build is only "done" if both pass

## Definition of Done

- `./install.sh` on a fresh Ubuntu 22.04/24.04 with Nautilus succeeds end-to-end
- Right-click → Scripts → Send to SFTP shows the host picker
- Files transfer to a configured host using key auth from `~/.ssh/config`, with a progress notification
- `make lint && make test` green
- CI green on `main`
- Repo has README, PLAN, LICENSE, CHANGELOG, CONTRIBUTING
