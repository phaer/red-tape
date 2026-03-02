# red-tape contrib modules

Optional module descriptors for output types outside red-tape's minimal core.
Pass them via `extraModules` in your `mkFlake` call.

## Available modules

| Module | File | Scans for | Produces |
|--------|------|-----------|----------|
| system-manager | `system-manager.nix` | `hosts/*/system-configuration.nix` | `systemConfigs.*` |

## How it works

Contrib modules are **standalone descriptors** — they don't replace the
core `hosts` module. Each module independently scans the same `hosts/`
directory for its own filenames. The core hosts module finds
`configuration.nix` and `darwin-configuration.nix`; the system-manager
module finds `system-configuration.nix`. No conflicts.

## Usage

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url        = "github:NixOS/nixpkgs/nixos-unstable";
    system-manager.url = "github:numtide/system-manager";
    red-tape.url       = "github:you/red-tape";
  };

  outputs = inputs:
    let rt = inputs.red-tape.lib;
    in rt {
      inherit inputs;
      extraModules.system-manager = import (inputs.red-tape + "/contrib/system-manager.nix") {
        inherit (rt) adios;
        scanHosts = rt._internal.scanHosts;
      };
    };
}
```

Then put your system-manager configs in `hosts/<name>/system-configuration.nix`.

## Writing your own

See the [custom modules section in HOWTO.md](../HOWTO.md#writing-custom-modules).

A contrib module descriptor is an attrset with:

- **`name`** — unique key (also used as the `extraModules` key)
- **`discover`** — `src -> value | null` — how to find files on disk
- **`optionsFn`** — `ctx -> options` — how to wire discovered data into adios options
- **`options`** — adios typed option declarations
- **`impl`** — `{ options, ... } -> attrset` — builds the flake outputs

The returned attrset from `impl` is merged into top-level flake outputs
by `collectAgnostic` (for system-agnostic modules) or transposed across
systems (for `perSystem = true` modules).
