# red-tape adios-flake module — per-system discovery
#
# Usage:
#   modules = [ (red-tape.lib.module { src = self; }) ];
#
# Discovers packages/, devshells/, checks/, formatter.nix and wires them
# into the per-system outputs that adios-flake expects.
{ discover, callFile, buildAll, filterPlatforms, withPrefix }:

{
  src,
  nixpkgs ? {},
  prefix ? null,
  inputs ? {},
  self ? null,
}:
let
  inherit (builtins)
    attrNames concatMap elem filter isPath
    listToAttrs map mapAttrs pathExists;

  resolvedSrc =
    if prefix != null then
      (if isPath prefix then prefix else src + "/${prefix}")
    else src;

  found = discover.discoverAll resolvedSrc;

  allInputs = (builtins.removeAttrs inputs [ "self" ])
    // (if self != null then { inherit self; } else {});

  hasCustomNixpkgs = (nixpkgs.config or {}) != {} || (nixpkgs.overlays or []) != [];
in
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
      if builtins.isAttrs i then (i.legacyPackages.${system} or {}) // (i.packages.${system} or {}) else i
    ) allInputs;
  };

  packages  = filterPlatforms system (buildAll scope found.packages);
  devShells = buildAll scope found.devshells;
  checks    = filterPlatforms system (buildAll scope found.checks);

  formatter = if found.formatter != null then callFile scope found.formatter {}
    else p.nixfmt-tree or p.nixfmt or (throw "red-tape: no formatter.nix and nixfmt-tree unavailable");

  pkgChecks = withPrefix "pkgs-" packages
    // listToAttrs (concatMap (pname:
      let tests = filterPlatforms system (packages.${pname}.passthru.tests or {});
      in map (t: { name = "pkgs-${pname}-${t}"; value = tests.${t}; }) (attrNames tests)
    ) (attrNames packages));
in
{
  inherit packages devShells formatter;
  checks = pkgChecks // withPrefix "devshell-" devShells // checks;
}
