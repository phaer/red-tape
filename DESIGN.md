# red-tape — Design Notes

## Architecture Overview

```
lib/internal.nix     Scanning and builder primitives
        ↑
modules/*           adios-flake modules (each imports the primitives it needs)
        ↓
lib/default.nix     Entry point: mkFlake + module re-export
        ↓
flake.nix           Public API
```

### lib/internal.nix

Scanning and builder primitives used by individual modules. Scanning functions only use `builtins.readDir`, `builtins.pathExists`, and path construction — no evaluation happens.

Scanning:
- **`scanDir path`** — Reads a directory and returns `{ name = { path; type; }; }` for each `.nix` file or subdirectory with `default.nix`. Strips `.nix` extensions.
- **`scanHosts hostsDir hostTypes`** — Scans `hosts/` subdirectories, matching against an ordered list of `{ type, file }` specs. First match wins.
- **`scanEntries { dir?, single?, singleName? }`** — Scans a directory for entries with optional single-file fallback. Used by packages, devshells, and checks.
- **`scanSubdirs path f`** — Lists subdirectories of a path and applies `f` to each. Used by modules (`scanSubdirs p scanDir`) and templates (`scanSubdirs p (p: { path = p; })`).

Building:
- **`callFile scope path extra`** — Calls a Nix file with the scope attrset, using `builtins.functionArgs` to determine which arguments to pass.
- **`entryPath entry`** — Extracts the filesystem path from a discovered entry.
- **`buildAll scope discovered`** — Maps `callFile` over all discovered entries.
- **`filterPlatforms system pkgs`** — Filters packages by `meta.platforms` (keeps those matching `system` or having no platform restriction).
- **`withPrefix prefix attrs`** — Prepends a string prefix to all attribute names.

### modules/

[adios-flake](https://github.com/Mic92/adios-flake) modules that handle both discovery and building for their output type. adios-flake is a flake-output wrapper around [adios](https://github.com/adisbladis/adios), a lightweight module system with explicit dependency declaration and topological ordering.

Each module imports the primitives it needs from `lib/internal.nix` and scans the filesystem itself. The `scan` module is a thin context provider (`resolvedSrc`, `self`, `inputs`).

```
scan ──→ scope ──→ packages  (scans packages/, package.nix)
              ├──→ devshells (scans devshells/, devshell.nix)
              ├──→ formatter (scans formatter.nix)
              └──→ checks    (scans checks/; also depends on packages, devshells, formatter, hosts)

scan ──→ hosts      (scans hosts/ via scanHosts; depends on contrib)
    ├──→ modules    (scans modules/{type}/; depends on contrib)
    ├──→ templates  (scans templates/)
    └──→ lib        (scans lib/default.nix)
```

**Per-system modules** (packages, devshells, formatter, checks) depend on `scope` which provides `{ system, pkgs, lib, flake, inputs, perSystem }`.

**System-agnostic modules** (hosts, modules, templates, lib) depend only on `scan` (plus `contrib` where extensible).

## Design Decisions

### Why adios-flake?

[adios-flake](https://github.com/Mic92/adios-flake) wraps [adios](https://github.com/adisbladis/adios), a lightweight module system with explicit dependency declaration and topological ordering. Each module declares its inputs (other modules it depends on) and gets their results injected. This avoids the complexity of NixOS-style module merging while still supporting composition.

### Why convention-over-configuration?

Most Nix projects follow similar patterns: packages in `packages/`, devshells in `devshells/`, etc. By scanning the filesystem, red-tape eliminates the need to manually wire each file into `flake.nix`. Adding a new package is as simple as creating a file. This approach is shared with [blueprint](https://github.com/numtide/blueprint).

### Why no overlays in core?

Overlays encourage global mutation of nixpkgs, which makes builds harder to reason about and reproduce. red-tape focuses on explicit package definitions via `callPackage`-style evaluation. Projects that need overlays can add them via `flake` passthrough.

### Why only nixosModules by default?

NixOS modules are the most common case. Darwin and home-manager modules are opt-in via contrib modules, keeping the core small and avoiding unnecessary dependencies.

## Extensibility

### Custom Host Types

Contrib modules provide two things that the `hosts` module picks up via its `contrib` input:

1. **`scanHostTypes`** — `{ type, file }` specs appended to `coreHostTypes` for host discovery
2. **`hostTypes.${type}`** — `{ outputKey, build }` for the builder

See `contrib/darwin.nix`, `contrib/home-manager.nix`, and `contrib/system-manager.nix` for examples.

### Custom Module Types

The `moduleTypes` option maps directory names under `modules/` to flake output keys:

```nix
{ home = "homeModules"; darwin = "darwinModules"; }
```

This can be set via contrib modules that set `"/red-tape/modules".moduleTypes`, or directly via `config` in `mkFlake`.

## Testing

Tests use [nix-unit](https://github.com/nix-community/nix-unit) and live in `tests/`:

- **Scanning tests** (`scan-dir.nix`, `discover.nix`) — Test scanning primitives and per-type patterns against fixtures
- **Builder tests** (`integration.nix`, `hosts.nix`, `modules-export.nix`, etc.) — Test build logic with mock pkgs
- **Module tree tests** (`module.nix`) — Test the full adios-flake module tree end-to-end
- **Extensibility tests** (`extensibility.nix`) — Test custom host types and module types
- **Prefix tests** (`prefix.nix`) — Test prefix-based discovery

All tests are aggregated in `tests/default.nix` and run via `nix run nixpkgs#nix-unit -- tests/default.nix`.
