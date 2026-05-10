# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-09

### Added
- Parse `~/.ssh/config` into selectable host list (`lib/parse_ssh.sh`)
- Yad/zenity dialog abstraction (`lib/ui.sh`)
- Remote directory browser over SSH (`lib/remote_browse.sh`)
- rsync transfer with progress parsing (`lib/transport.sh`)
- Recent destinations store (`lib/recent.sh`)
- Desktop notifications via libnotify (`lib/notify.sh`)
- Main entrypoint orchestrating all libs (`bin/send-to-sftp`)
- File manager integrations for Nautilus, Nemo, Caja, Thunar
- Installer/uninstaller script (`install.sh`)
- Unit tests with bats-core (`tests/parse_ssh.bats`, `tests/recent.bats`)
- CI pipeline with shellcheck + bats on Ubuntu 22.04/24.04
- MIT License (holder: MMTE)

[0.1.0]: https://github.com/MMTE/send-to-sftp/releases/tag/v0.1.0
