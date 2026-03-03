# red-tape contrib modules

Optional adios-flake modules for output types outside red-tape's minimal core.
Pass them via `extraModules` in your `mkFlake` call.

## Available modules

| Module | File | Scans for | Produces |
|--------|------|-----------|----------|
| system-manager | `system-manager.nix` | `hosts/*/system-configuration.nix` | `systemConfigs.*` |

## Usage

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url        = "github:NixOS/nixpkgs/nixos-unstable";
    system-manager.url = "github:numtide/system-manager";
    red-tape.url       = "github:phaer/red-tape";
  };

  outputs = inputs:
    inputs.red-tape.mkFlake {
      inherit inputs;
      extraModules = [
        (import (inputs.red-tape + "/contrib/system-manager.nix"))
      ];
    };
}
```

Then put your system-manager configs in `hosts/<name>/system-configuration.nix`.

## Writing your own

Contrib modules are standard adios-flake config modules. They extend red-tape by
setting options on the `/red-tape/scan` and `/red-tape/hosts` modules:

- **`/red-tape/scan`.extraHostTypes** — list of `{ type; file; }` sentinel descriptors,
  appended to the core types so `hosts/` scanning picks them up.
- **`/red-tape/hosts`.extraHostBuilders** — attrset of `type → { outputKey; build }`,
  where `build` receives `{ name, info, specialArgs, allInputs }`.

```nix
# Example: nix-on-droid support
_: {
  "/red-tape/scan".extraHostTypes = [
    { type = "nix-on-droid"; file = "droid-configuration.nix"; }
  ];

  "/red-tape/hosts".extraHostBuilders.nix-on-droid = {
    outputKey = "nixOnDroidConfigurations";
    build = { name, info, specialArgs, allInputs }:
      allInputs.nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = import allInputs.nixpkgs { system = "aarch64-linux"; };
        modules = [ info.configPath ];
        extraSpecialArgs = specialArgs // { hostName = name; };
      };
  };
}
```
