# red-tape

> 🚨 **WARNING:** This is vibe-coded slop. The "author" talked to an LLM until
> something worked. Expect sharp edges, questionable decisions, and
> documentation that may be more confident than the code deserves.

Convention-based Nix project builder on top of [adios](https://github.com/adisbladis/adios).

Drop `.nix` files in the right directories, get flake outputs with zero boilerplate.
~660 lines in a single `default.nix`.

## The Problem

A typical `flake.nix` for a project with a package, devshell, formatter,
NixOS module, and a host configuration looks something like this:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = nixpkgs.legacyPackages.${system};
        inherit system;
      });
    in {
      packages = forAllSystems ({ pkgs, ... }: {
        default = pkgs.callPackage ./package.nix {};
        widget = pkgs.callPackage ./packages/widget.nix {};
      });
      devShells = forAllSystems ({ pkgs, ... }: {
        default = pkgs.mkShell { packages = [ pkgs.nodejs ]; };
      });
      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt-tree);
      checks = forAllSystems ({ pkgs, system, ... }: {
        pkgs-default = self.packages.${system}.default;
        pkgs-widget = self.packages.${system}.widget;
        devshell-default = self.devShells.${system}.default;
      });
      nixosModules.server = ./modules/nixos/server.nix;
      nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
        modules = [ ./hosts/myhost/configuration.nix ];
        specialArgs = { inherit self; };
      };
    };
}
```

This is tedious. Every new package needs wiring in three places (packages,
checks, flake.nix). The `forAllSystems` dance repeats for every output type.
Adding a devshell means updating checks too. It doesn't scale.

## The Solution

With red-tape, you just put files in the right place:

```nix
# flake.nix — the entire thing
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.red-tape.url = "github:you/red-tape";

  outputs = inputs: inputs.red-tape.lib { inherit inputs; };
}
```

```
my-project/
├── flake.nix                          # ← 6 lines above
├── package.nix                        # → packages.default + checks.pkgs-default
├── packages/widget.nix                # → packages.widget + checks.pkgs-widget
├── devshell.nix                       # → devShells.default + checks.devshell-default
├── hosts/myhost/configuration.nix     # → nixosConfigurations.myhost
└── modules/nixos/server.nix           # → nixosModules.server
```

No `forAllSystems`. No manual check wiring. Add a file, get an output.

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
├── overlay.nix              → overlays.default
├── overlays/
│   └── my-tools.nix         → overlays.my-tools
├── hosts/
│   ├── myhost/
│   │   └── configuration.nix       → nixosConfigurations.myhost
│   ├── mymac/
│   │   └── darwin-configuration.nix → darwinConfigurations.mymac
│   └── custom/
│       └── default.nix              → escape hatch (returns { class, value })
├── modules/
│   ├── nixos/server.nix     → nixosModules.server
│   ├── darwin/defaults.nix  → darwinModules.defaults
│   └── home/shared.nix      → homeModules.shared
├── templates/
│   ├── default/             → templates.default
│   └── minimal/             → templates.minimal
└── lib/default.nix          → lib
```

## How Files Are Called

Every `.nix` file under `packages/`, `devshells/`, `checks/`, and
`formatter.nix` is called like `callPackage` — red-tape inspects the
function arguments and passes only what's requested:

```nix
# packages/widget.nix
{ pkgs, lib, pname, ... }:
pkgs.stdenv.mkDerivation {
  inherit pname;
  version = "1.0";
  src = ./.;
}
```

Available arguments:

| Arg | Value |
|-----|-------|
| `pkgs` | nixpkgs for the current system |
| `lib` | `pkgs.lib` |
| `system` | Current system string |
| `pname` | Derived from filename (`widget.nix` → `"widget"`) |
| `perSystem` | Cross-input resolution (see below) |
| `flake` | The flake self-reference |
| `inputs` | All flake inputs |

You only take what you need. `{ pkgs, ... }:` is the common case.

### Cross-Input Resolution (`perSystem`)

`perSystem` provides `legacyPackages.<system>` and `packages.<system>` from
each input, keyed by input name:

```nix
# devshell.nix
{ pkgs, perSystem, ... }:
pkgs.mkShell {
  packages = [ perSystem.some-tool-flake.default ];
}
```

This avoids the `inputs.foo.packages.${system}.bar` boilerplate.

> **Note:** `perSystem`, `flake`, and `inputs` are only available in flake
> mode. Traditional mode (`eval`) receives only `pkgs`, `lib`, `system`,
> and `pname`.

## Walkthrough

### Packages

```nix
# package.nix
{ pkgs, pname, ... }:
pkgs.writeShellScriptBin pname ''
  echo "Hello!"
''
```

This becomes `packages.default` and automatically `checks.pkgs-default`.

```nix
# packages/widget.nix
{ pkgs, pname, ... }:
pkgs.stdenv.mkDerivation { inherit pname; src = ./.; }
```

If a package has `passthru.tests`, those become checks too:

```
packages.widget                             → checks.pkgs-widget
packages.cli.passthru.tests.integration     → checks.pkgs-cli-integration
```

### Devshells

```nix
# devshell.nix
{ pkgs, ... }:
pkgs.mkShell { packages = [ pkgs.nodejs pkgs.typescript ]; }
```

Becomes `devShells.default` and `checks.devshell-default`.

For multiple devshells, use `devshells/backend.nix` → `devShells.backend`.

### Formatter

```nix
# formatter.nix
{ pkgs, ... }:
pkgs.nixfmt-tree
```

If you don't create this file, red-tape falls back to `nixfmt-tree`
automatically. You only need it to choose a different formatter.

### Checks

Auto-checks from packages and devshells are usually enough. For custom checks:

```nix
# checks/lint.nix
{ pkgs, pname, ... }:
pkgs.runCommand pname {} ''
  ${pkgs.statix}/bin/statix check ${./.}
  touch $out
''
```

### NixOS Hosts

```nix
# hosts/myhost/configuration.nix
{ config, pkgs, flake, inputs, hostName, ... }:
{
  networking.hostName = hostName;  # "myhost" — derived from directory name
}
```

red-tape calls `nixpkgs.lib.nixosSystem` for you, passing
`{ flake, inputs, hostName }` as `specialArgs`.

#### Darwin hosts

```nix
# hosts/mymac/darwin-configuration.nix
{ config, pkgs, flake, inputs, hostName, ... }:
{ /* nix-darwin configuration */ }
```

Requires `inputs.nix-darwin` in your flake inputs.

#### Custom host escape hatch

```nix
# hosts/weird/default.nix
{ flake, inputs, hostName }:
{
  class = "nixos";  # or "nix-darwin"
  value = inputs.nixpkgs.lib.nixosSystem { /* your custom setup */ };
}
```

### Modules

```nix
# modules/nixos/server.nix
{ config, lib, pkgs, ... }:
{
  options.services.myapp = { ... };
  config = { ... };
}
```

Re-exported as `nixosModules.server`. The directory name determines the output:

| Directory | Output |
|-----------|--------|
| `modules/nixos/` | `nixosModules` |
| `modules/darwin/` | `darwinModules` |
| `modules/home/` | `homeModules` |

If a module needs to know about the flake, use publisher args:

```nix
# modules/nixos/myapp.nix
{ flake, inputs }:    # ← called once at export time
{ config, lib, ... }: # ← the actual NixOS module
{
  options.services.myapp.package = lib.mkOption {
    default = flake.packages.${config.nixpkgs.hostPlatform.system}.default;
  };
}
```

### Overlays

```nix
# overlay.nix — becomes overlays.default
{ ... }:
final: prev: {
  my-patched-pkg = prev.something.overrideAttrs { ... };
}
```

Overlay files can accept `{ lib, flake, inputs, ... }` but **not**
`pkgs` or `system` — overlays are system-agnostic functions.

### Templates

```
templates/
├── default/
│   ├── flake.nix     # description read from here
│   └── ...
└── minimal/
    ├── flake.nix
    └── ...
```

### Library Functions

```nix
# lib/default.nix
{ flake, inputs }:
{
  greet = name: "Hello, ${name}!";
}
```

The `{ flake, inputs }` wrapper is optional — a plain attrset works too.

## Auto-Checks

Packages and devshells automatically become checks:

- `packages.foo` → `checks.pkgs-foo`
- `packages.foo.passthru.tests.bar` → `checks.pkgs-foo-bar`
- `devShells.default` → `checks.devshell-default`

User-defined checks in `checks/` take precedence over auto-generated ones.

## Configuration

```nix
inputs.red-tape.lib {
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

Returns `{ packages, devShells, formatter, checks, overlays, shell, ... }`.

## Architecture

Everything lives in a single `default.nix` (~660 sloc). Built on
[adios](https://github.com/adisbladis/adios) for evaluation memoization.
The flake entry point (`flake.nix`) just does `import ./. {}`.

Adios modules (all conditional on discovery):

```
Per-system (re-evaluated per system override):
  /nixpkgs    — data-only: { system, pkgs }
  /packages   — builds packages from discovered paths
  /devshells  — builds devshells from discovered paths
  /formatter  — selects formatter (fallback nixfmt-tree)
  /checks     — builds user-defined checks

System-agnostic (evaluated once, memoized across overrides):
  /hosts          — nixosConfigurations, darwinConfigurations
  /overlays       — nixpkgs overlay functions
  /modules-export — nixosModules, darwinModules, homeModules
```

Discovery is a **plain function** (not an adios module) — its results are
passed as options. Templates and lib export are also plain functions.

For multi-system evaluation, the first system does a full eval, subsequent
systems use `override` to change only `/nixpkgs`, which lets adios skip
re-evaluation of modules that don't depend on system-specific options.

## Comparison with flake-parts

flake-parts gives you a module system to *configure* outputs. red-tape gives
you file conventions — write the `.nix` file and the output appears.

### Key differences

- **Module system**: flake-parts uses the NixOS module system (`lib.evalModules`)
  with merging, priorities, `mkIf`. red-tape uses adios — leaner, no merging,
  explicit dependencies.

- **Evaluation**: flake-parts evaluates the full module tree per system.
  red-tape evaluates once, then uses adios `override` — system-agnostic
  modules are evaluated once and shared.

- **Integrations**: flake-parts has a large ecosystem of modules (treefmt,
  devenv, hercules-ci). red-tape is minimal; niche integrations go in
  contrib modules or `extraModules`.

**Use red-tape** if you want zero-boilerplate from file conventions.
**Use flake-parts** if you need deep module composition or third-party integrations.

### Side-by-side

```nix
# ── flake-parts ──────────────────────────────
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-darwin" ];
    perSystem = { pkgs, self', ... }: {
      packages.default = pkgs.callPackage ./package.nix {};
      packages.widget = pkgs.callPackage ./packages/widget.nix {};
      devShells.default = pkgs.mkShell { packages = [ pkgs.nodejs ]; };
      checks = {
        pkg-default = self'.packages.default;
        pkg-widget = self'.packages.widget;
        devshell = self'.devShells.default;
      };
      formatter = pkgs.nixfmt-tree;
    };
    flake = {
      nixosModules.server = ./modules/nixos/server.nix;
      nixosConfigurations.myhost = inputs.nixpkgs.lib.nixosSystem {
        modules = [ ./hosts/myhost/configuration.nix ];
      };
    };
  };
}
```

```nix
# ── red-tape ─────────────────────────────────
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    red-tape.url = "github:you/red-tape";
  };
  outputs = inputs: inputs.red-tape.lib { inherit inputs; };
}
# Then just have the files:
#   package.nix  packages/widget.nix  devshell.nix
#   hosts/myhost/configuration.nix  modules/nixos/server.nix
```

## Comparison with blueprint

[blueprint](https://github.com/numtide/blueprint) is the closest relative —
both are convention-based with nearly identical filesystem conventions.
A blueprint project can be migrated to red-tape (or vice versa) by changing
a single line in `flake.nix`.

### Differences

| | blueprint | red-tape |
|-|-----------|----------|
| **Overlays** | ✗ | ✓ (`overlay.nix` / `overlays/`) |
| **Formatter fallback** | Requires `formatter.nix` | Falls back to `nixfmt-tree` |
| **Host auto-checks** | ✓ (builds closures as checks) | ✗ (too expensive for `nix flake check`) |
| **TOML devshells** | ✓ | ✗ |
| **Home-manager users under hosts** | ✓ | ✗ |
| **System-manager/RPi hosts** | ✓ | ✗ |
| **Memoization** | None (full eval per system) | adios (system-agnostic work evaluated once) |
| **Flake inputs** | Requires `nixpkgs` | None (npins internally) |

**Use red-tape** for adios memoization, overlays, minimal formatter fallback.
**Use blueprint** for home-manager user wiring, TOML devshells, larger community.

## Writing Custom Modules

red-tape is built on adios modules. Add your own via `extraModules`:

### Module Descriptors

```nix
{
  name = "my-module";

  # red-tape metadata
  discover  = src: ...;            # src -> value | null (null = skip)
  optionsFn = { discovered, ... }: # wire discovered data into adios options
    { discovered = discovered.my-module; };
  perSystem  = false;              # true: depends on /nixpkgs, transposed

  # adios fields
  options = {
    discovered = { type = types.attrs; default = {}; };
  };
  impl = { options, ... }: {
    myOutputs = buildThings options.discovered;
  };
}
```

### The Descriptor Contract

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Unique key — also the key in `extraModules` |
| `discover` | no | `src -> value \| null` — file scanning. Absent = always active |
| `optionsFn` | no | `ctx -> attrset` — wires `discovered` into adios options |
| `perSystem` | no | `bool`, default `false`. `true` = per-system, transposed |
| `options` | yes | adios typed option declarations |
| `impl` | yes | `{ options, inputs, ... } -> attrset` — builds flake outputs |

The `optionsFn` context contains:
`{ discovered, extraScope, agnosticScope, flakeInputs, self }`

### Example: nix-on-droid support

```nix
# nix/modules/nix-on-droid.nix
{ adios, scanHosts }:
let types = adios.types;
in {
  name = "nix-on-droid";

  discover = src:
    scanHosts (src + "/hosts") [
      { type = "nix-on-droid"; file = "droid-configuration.nix"; }
    ];

  optionsFn = { discovered, flakeInputs, self, ... }:
    { discovered = discovered.nix-on-droid; inherit flakeInputs self; };

  options = {
    discovered  = { type = types.attrs; default = {}; };
    flakeInputs = { type = types.attrs; default = {}; };
    self        = { type = types.any;   default = null; };
  };

  impl = { options, ... }:
    let
      inherit (options) flakeInputs self;
      nix-on-droid = flakeInputs.nix-on-droid
        or (throw "red-tape: nix-on-droid module needs inputs.nix-on-droid");
    in {
      nixOnDroidConfigurations = builtins.mapAttrs (hostName: hostInfo:
        nix-on-droid.lib.nixOnDroidConfiguration {
          pkgs = import flakeInputs.nixpkgs { system = "aarch64-linux"; };
          modules = [ hostInfo.configPath ];
          extraSpecialArgs = {
            flake = self;
            inputs = flakeInputs // (if self != null then { inherit self; } else {});
            inherit hostName;
          };
        }
      ) options.discovered;
    };
}
```

Wire it in:

```nix
# flake.nix
outputs = inputs:
  let rt = inputs.red-tape.lib;
  in rt {
    inherit inputs;
    extraModules.nix-on-droid = import ./nix/modules/nix-on-droid.nix {
      inherit (rt) adios;
      scanHosts = rt._internal.scanHosts;
    };
  };
```

### Example: a new output type

```nix
# nix/modules/deploy.nix
{ adios, scanDir }:
let types = adios.types;
in {
  name = "deploy";

  discover = src:
    let v = scanDir (src + "/deploy");
    in if v == {} then null else v;

  optionsFn = { discovered, flakeInputs, self, ... }:
    { discovered = discovered.deploy; inherit flakeInputs self; };

  options = {
    discovered  = { type = types.attrs; default = {}; };
    flakeInputs = { type = types.attrs; default = {}; };
    self        = { type = types.any;   default = null; };
  };

  impl = { options, ... }: {
    deploy = builtins.mapAttrs (name: entry:
      import (if entry.type == "directory" then entry.path + "/default.nix" else entry.path)
    ) options.discovered;
  };
}
```

## License

MIT