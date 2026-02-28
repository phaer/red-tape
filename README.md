# red-tape

Convention-based Nix project builder on top of [adios](https://github.com/msteen/adios).

Drop `.nix` files in the right directories, get flake outputs with zero boilerplate.

## Quick Start

```nix
# flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.red-tape.url = "github:you/red-tape";

  outputs = inputs: inputs.red-tape.mkFlake { inherit inputs; };
}
```

## Directory Conventions

```
your-project/
├── package.nix              → packages.default
├── packages/
│   ├── foo.nix              → packages.foo
│   └── bar/default.nix      → packages.bar
├── devshell.nix             → devShells.default
├── devshells/
│   └── backend.nix          → devShells.backend
├── formatter.nix            → formatter (fallback: nixfmt-tree)
├── checks/
│   └── lint.nix             → checks.lint
├── hosts/
│   ├── myhost/
│   │   └── configuration.nix      → nixosConfigurations.myhost
│   └── mymac/
│   │   └── darwin-configuration.nix → darwinConfigurations.mymac
│   └── custom/
│       └── default.nix             → escape hatch (returns { class, value })
├── modules/
│   ├── nixos/server.nix     → nixosModules.server
│   ├── darwin/defaults.nix  → darwinModules.defaults
│   └── home/shared.nix      → homeModules.shared
├── templates/
│   ├── default/             → templates.default
│   └── minimal/             → templates.minimal
└── lib/default.nix          → lib (receives { flake, inputs })
```

## How It Works

1. **Discover** — Scan the source tree for files matching conventions
2. **Evaluate** — Per-system outputs go through adios modules for memoization
3. **Assemble** — Auto-checks from packages and devshells, system-agnostic outputs merged

### Per-System Outputs (transposed across systems)

| Directory | Output | Notes |
|-----------|--------|-------|
| `package.nix` / `packages/` | `packages.<name>` | Files receive `{ pkgs, pname, lib, ... }` |
| `devshell.nix` / `devshells/` | `devShells.<name>` | Files receive `{ pkgs, pname, lib, ... }` |
| `formatter.nix` | `formatter` | Falls back to `nixfmt-tree` |
| `checks/` | `checks.<name>` | Files receive `{ pkgs, pname, lib, ... }` |

### System-Agnostic Outputs

| Directory | Output | Notes |
|-----------|--------|-------|
| `hosts/*/configuration.nix` | `nixosConfigurations.*` | specialArgs: `{ flake, inputs, hostName }` |
| `hosts/*/darwin-configuration.nix` | `darwinConfigurations.*` | Requires `inputs.nix-darwin` |
| `hosts/*/default.nix` | classified by returned `class` | Escape hatch |
| `modules/<type>/` | `nixosModules`, `darwinModules`, `homeModules` | Path re-export |
| `templates/*/` | `templates.*` | Description from `flake.nix` |
| `lib/default.nix` | `lib` | Receives `{ flake, inputs }` |

### Auto-Checks

Packages and devshells automatically become checks:

- `packages.foo` → `checks.pkgs-foo`
- `packages.foo.passthru.tests.bar` → `checks.pkgs-foo-bar`
- `devShells.default` → `checks.devshell-default`

User-defined checks in `checks/` take precedence over auto-generated ones.

## CallPackage Scope

Every `.nix` file under `packages/`, `devshells/`, `checks/`, and `formatter.nix`
is called with arguments matched from:

| Arg | Value |
|-----|-------|
| `pkgs` | nixpkgs for the current system |
| `lib` | `pkgs.lib` |
| `system` | Current system string |
| `pname` | Derived from filename |
| `perSystem` | Cross-input resolution (see below) |
| `flake` | The flake self-reference |
| `inputs` | All flake inputs |

### Cross-Input Resolution (`perSystem`)

`perSystem` merges `legacyPackages.<system>` and `packages.<system>` from all
inputs into a flat namespace:

```nix
# In package.nix:
{ pkgs, perSystem, ... }:
pkgs.mkShell {
  packages = [ perSystem.some-input.some-package ];
}
```

## Configuration

```nix
inputs.red-tape.mkFlake {
  inherit inputs;

  # Override source root (for monorepos)
  prefix = "nix";

  # Target systems
  systems = [ "x86_64-linux" "aarch64-darwin" ];

  # Nixpkgs config
  nixpkgs = {
    config.allowUnfree = true;
    overlays = [ my-overlay ];
  };

  # Extra adios modules
  extraModules = { ... };

  # Third-party module config (maps to adios option paths)
  config = { ... };
}
```

## Traditional Mode (npins/niv)

```nix
# default.nix
let
  sources = import ./npins;
  red-tape = import sources.red-tape;
  pkgs = import sources.nixpkgs {};
in
red-tape.eval {
  inherit pkgs;
  src = ./.;
}
```

Returns `{ packages, devShells, formatter, checks, shell, ... }`.

## Architecture

Built on [adios](https://github.com/msteen/adios) for evaluation memoization.
The adios module tree has five nodes:

```
/nixpkgs    — data-only: { system, pkgs }
/packages   — builds packages from discovered paths
/devshells  — builds devshells from discovered paths
/formatter  — selects formatter
/checks     — builds user-defined checks
```

Discovery is a **plain function** (not an adios module) — its results are
passed as options. System-agnostic outputs (hosts, modules, templates, lib)
are assembled outside the adios tree.

For multi-system evaluation, the first system does a full `eval`, subsequent
systems use `override` to change only `/nixpkgs`, which lets adios skip
re-evaluation of modules that don't depend on system-specific options.

## License

MIT
