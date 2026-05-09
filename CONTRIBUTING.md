# Contributing

Thanks for your interest in contributing to **send-to-sftp**!

## Running Tests

```bash
./tests/run.sh
```

Or via Make:

```bash
make test
```

Test fixtures live in `tests/fixtures/`. Temporary files created during tests go to `tests/tmp/` (gitignored).

## Code Style

- **Bash 4+** — target `#!/usr/bin/env bash`
- **shellcheck** — all shell files must pass `shellcheck` with zero errors. Run `make lint`.
- **Quote everything** — always quote variable expansions: `"$var"`, not `$var`
- Use `local` for function-scoped variables
- Use `readonly` for constants
- Prefer `printf` over `echo` for output formatting
- No external dependencies beyond standard GNU coreutils and OpenSSH `sftp`

## Commit Conventions

We use [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix    | Purpose                                |
|-----------|----------------------------------------|
| `feat:`   | New feature                            |
| `fix:`    | Bug fix                                |
| `chore:`  | Maintenance, tooling, config changes   |
| `test:`   | Adding or updating tests               |
| `ci:`     | CI/CD workflow changes                 |
| `docs:`   | Documentation-only changes             |

Example: `feat(nemo): add Nemo file manager integration`

## Submitting Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Make your changes and ensure `make lint` and `make test` pass
4. Commit using conventional commit messages
5. Push and open a pull request against `main`

## Adding New File Manager Integrations

1. Create a new directory under `integrations/<file-manager>/`
2. Add a `<file-manager>.sh` script that accepts file paths as arguments
3. The script should source `lib/sftp.sh` and call the shared upload logic
4. Add file-manager-specific install/cleanup logic to `install.sh`
5. Add tests in `tests/` covering the integration script
6. Update `README.md` with installation instructions for the new file manager
