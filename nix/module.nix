# red-tape adios-flake module — unified discovery
#
# Usage:
#   modules = [ (red-tape.lib.module { src = self; }) ];
#
# Discovers packages/, devshells/, checks/, formatter.nix (per-system)
# and hosts/, modules/, overlays/, templates/, lib/ (flake-scoped).
# adios-flake routes keys to /_collector or /_flake automatically.
{ discover, callFile, buildAll, filterPlatforms, withPrefix
, buildModules, buildHosts
}:

{
  src,
  nixpkgs ? {},
  prefix ? null,
  inputs ? {},
  self ? null,
  moduleTypeAliases ? {},
}:
let
  inherit (builtins)
    attrNames concatMap elem filter isAttrs isFunction isPath
    listToAttrs map mapAttrs pathExists removeAttrs;

  resolvedSrc =
    if prefix != null then
      (if isPath prefix then prefix else src + "/${prefix}")
    else src;

  found = discover.discoverAll resolvedSrc;

  allInputs = (removeAttrs inputs [ "self" ])
    // (if self != null then { inherit self; } else {});

  hasCustomNixpkgs = (nixpkgs.config or {}) != {} || (nixpkgs.overlays or []) != [];

  # ── Flake-scoped outputs (computed once, no pkgs needed) ─────────

  agnostic = { flake = self; inputs = allInputs; };

  hosts = if found.hosts != {} then buildHosts { discovered = found.hosts; inherit allInputs self; } else {};

  flakeResult =
    (if found.overlays != {} then { overlays = buildAll agnostic found.overlays; } else {})
    // (removeAttrs hosts [ "autoChecks" ])
    // (if found.modules != {} then buildModules {
        discovered = found.modules; inherit allInputs self;
        extraTypeAliases = moduleTypeAliases;
      } else {})
    // (let t = mapAttrs (name: e: { inherit (e) path; description =
          let f = e.path + "/flake.nix"; in if pathExists f then (import f).description or name else name;
        }) found.templates; in if t != {} then { templates = t; } else {})
    // (let l = if found.lib == null then {} else let m = import found.lib;
          in if isFunction m then m { flake = self; inputs = allInputs; } else m;
        in if l != {} then { lib = l; } else {});

in
# The returned function is an adios-flake ergonomic module.
# It receives per-system args and returns both per-system and flake-scoped
# keys. adios-flake routes them via /_collector and /_flake respectively.
{ pkgs, system, ... }:
let
  p = if hasCustomNixpkgs
    then import (inputs.nixpkgs or (throw "red-tape: nixpkgs config/overlays require inputs.nixpkgs")) {
      inherit system; config = nixpkgs.config or {}; overlays = nixpkgs.overlays or [];
    }
    else pkgs;

  scope = {
    inherit system;
    pkgs = p;
    lib = p.lib;
    flake = self;
    inputs = allInputs;
    perSystem = mapAttrs (_: i:
      if isAttrs i then (i.legacyPackages.${system} or {}) // (i.packages.${system} or {}) else i
    ) allInputs;
  };

  packages  = filterPlatforms system (buildAll scope found.packages);
  devShells = buildAll scope found.devshells;
  checks    = filterPlatforms system (buildAll scope found.checks);

  formatter = if found.formatter != null then callFile scope found.formatter {}
    else p.nixfmt-tree or p.nixfmt or (throw "red-tape: no formatter.nix and nixfmt-tree unavailable");

  # Host auto-checks: build system.build.toplevel for matching hosts
  hostAutoChecks =
    let ac = hosts.autoChecks or null;
    in if ac != null then ac system else {};

  pkgChecks = withPrefix "pkgs-" packages
    // listToAttrs (concatMap (pname:
      let tests = filterPlatforms system (packages.${pname}.passthru.tests or {});
      in map (t: { name = "pkgs-${pname}-${t}"; value = tests.${t}; }) (attrNames tests)
    ) (attrNames packages));
in
# Per-system keys
{
  inherit packages devShells formatter;
  checks = hostAutoChecks // pkgChecks // withPrefix "devshell-" devShells // checks;
}
# Flake-scoped keys (routed to /_flake by adios-flake)
// flakeResult
