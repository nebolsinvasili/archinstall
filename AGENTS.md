# AGENTS.md

Bash-based Arch Linux setup/installer toolkit. No build system, no test framework, no linter, no CI, no git repo. All scripts are Bash with `set -euo pipefail`.

## Environment init: `lib/init.sh`

Every script (setup/config/install/standalone) locates the repo root itself and sources `lib/init.sh`. There are **no hardcoded absolute repo paths** — the repo may live anywhere.

The standard preamble (used by `dependencies_installer.sh:50` and the top of every `setup.sh`/`install.sh`):

```bash
ROOT_DIR="$SCRIPT_DIR"
while [[ ! -d "$ROOT_DIR/pkg-installer" && "$ROOT_DIR" != "/" ]]; do
    ROOT_DIR="$(dirname "$ROOT_DIR")"
done
[[ -f "$ROOT_DIR/lib/init.sh" ]] || { echo "Не найден корень проекта (маркер 'pkg-installer')." >&2; exit 1; }
source "$ROOT_DIR/lib/init.sh"
```

The repo root marker is a `pkg-installer/` directory. Before the preamble, scripts define `SCRIPT_DIR` from `dirname "${BASH_SOURCE[0]}"`.

`lib/init.sh` is idempotent (module guards `__*.sh`). It exports `ROOT_DIR`, `LIB_DIR` (from `BASH_SOURCE[0]`), then sources, in order: `core.sh` (exports `PKG_INSTALLER_DIR`, `CONFIGS_DIR`, `CACHE_DIR`, `TMP_DIR`, `LOG_DIR` default `$ROOT_DIR/log`, and `mkdir`-s them), `env.sh` (mkdir `$ROOT_DIR/bin`, prepends it to `PATH`, sets `LC_ALL/LANG=C.UTF-8`), `colors.sh`, `icons.sh`, `logging.sh` + `log_init` (`log_*`, `log_title`, `log_separator`), `utils.sh` (`command_exists` et al.), `path_helpers.sh` (`project_path`, `config_path`, `lib_path`).

To add a shared helper, put it in a new `lib/<name>.sh` with a `__<NAME>_SH` guard and source it from `lib/init.sh`.

## Package-install engine

`pkg-installer/dependencies_installer.sh` is the core. Pipeline: `parse_args -> ensure_prereqs -> validate_managers -> install_dependency_tree -> show_install_report`.

- **Managers**: only `pacman` and `yay` are registered/active (`dependencies_installer.sh:75-97`). To add a manager, create `pkg-installer/managers/<name>.sh` defining `pkg_exists_<name>` + `install_<name>`, source it, and call `register_manager`. Other managers (paru/apt/dnf/zypper) exist only as commented-out stubs.
- **Dependency files** are JSON with named blocks; each block has `packages[]` and optional `manager`/`enabled`. Both inherit down nested objects (`parser.sh:9-13`). Block names become dotted paths.
- **manager resolution** (`registry.sh:resolve_managers`): `auto` tries pacman first, then yay; a preferred manager (e.g. `"manager": "yay"`) is tried first, then the rest.
- Packages that no manager can resolve are logged per-run to `missingApps_<timestamp>.log` (dir controlled by `MISSING_DIR`, default `$SCRIPT_DIR`).
- Flags: `-f/--file FILE`, `-p/--prog PKG...`, `-n/--dry-run`, `-v/--verbose` (`--file` and `--prog` are mutually exclusive).
- Requires `jq` (installed by `pkg-installer/prereq.sh`, `PREREQ_PACKAGES` lives in `dependencies_installer.sh:32`) and `dialog`.
- `pkg-installer/prereq.sh` (formerly `bootstrap.sh`) checks/installs prereq packages, guarded by `ensure_prereqs`.

## Architecture / directory roles

- `configs/<name>/` — dotfile/tool setups, each a self-contained unit: `setup.sh` + `dependencies.json` (+ optional `config/`, `config.sh`, `modules/`).
- `programs/cli|dev|office/<name>/` — per-app setups, same pattern; `langs/*` and `office/*` use a standalone `install.sh` instead of the engine.
- `drivers/<name>/`, `managers/aur/` — device drivers and the AUR (yay) installer.
- `lib/` — shared shell libraries, wired through `lib/init.sh` (colors, icons, logging, utils, path helpers, env, core).
- `scripts/` — standalone utility scripts (`proxy-setup.sh`, `mount_disk.sh`) with the same preamble.
- `cache/`, `log/` — runtime scratch dirs (default `LOG_DIR` is `$ROOT_DIR/log`); safe to ignore.
- `builder/archinstall` — entrypoint of the separate EasyArch OS installer (interactive disk/menu tool), **not** part of the pkg-installer flow. It only resolves `SCRIPT_DIR`, sources the modules from `builder/lib/` and calls `main_installation`, so the whole `builder/` directory must be present. Modules: `core.sh` (globals, banner), `ui.sh`, `pacman.sh`, `disk.sh`, `partition.sh`, `locale.sh`, `user.sh`, `aur.sh`, `hardware.sh`, `bootloader.sh`, `desktop.sh`, `kernel.sh`, `menus.sh`, `install.sh`; each has a `__<NAME>_SH` guard and is not run standalone. `builder/README.md` describes the EasyArch project.
- `test/test.sh` — a `dialog` menu mock, not a real test suite. There are no meaningful tests; verify changes by running the affected `setup.sh` with a dry-run (`-n`, expects to stop at `sudo`/`yay`).

## Conventions

- **Language**: script comments, log messages, and UI strings are in Russian (Cyrillic). Preserve this style; do not translate existing messages.
- **Standard setup.sh pattern**: preamble above → define `DEPENDENCIES_FILE="$SCRIPT_DIR/dependencies.json"` → run `"$PKG_INSTALLER_DIR/dependencies_installer.sh" --file "$DEPENDENCIES_FILE" "$@"` → then optional `<name>.sh config` → then dotfiles via `stow`. Dotfiles use GNU stow: `[ -d config ] && stow -R -v -t ~/.config config`.
- Engine invocation inside a script must use `"$PKG_INSTALLER_DIR/dependencies_installer.sh"` (env-provided) — never an absolute path.
- Script entrypoints guard with `[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"`.
- Every script must remain Bash (globals like `declare -Ag MANAGERS`, namerefs are used). Don't convert to sh.
- `.env` at root is empty and unused. There is no environment bootstrap beyond `lib/init.sh`.