# /packages — Per-system package builder
#
# Imports each discovered package file via callPackage-style invocation.
# Each .nix file receives: { pkgs, system, pname, lib, ... }
#
# Discovered paths and extraScope (perSystem, flake, inputs) are passed
# as options by the entry point.

{ types, ... }:
let
  inherit (builtins) mapAttrs intersectAttrs functionArgs;

  filterPlatforms = import ../lib/filter-platforms.nix;
in
{
  name = "packages";

  inputs = {
    nixpkgs = { path = "/nixpkgs"; };
  };

  options = {
    discovered = {
      type = types.attrs;
      default = {};
    };
    extraScope = {
      type = types.attrs;
      default = {};
    };
  };

  impl = { inputs, options, ... }:
    let
      system = inputs.nixpkgs.system;
      pkgs = inputs.nixpkgs.pkgs;

      baseScope = {
        inherit pkgs system;
        lib = pkgs.lib;
      } // options.extraScope;

      callPkg = path: extraArgs:
        let
          fn = import path;
          args = functionArgs fn;
          allArgs = baseScope // extraArgs;
        in
        fn (intersectAttrs args allArgs);

      buildPkg = pname: entry:
        let
          path = if entry.type == "directory" then entry.path + "/default.nix" else entry.path;
        in
        callPkg path { inherit pname; };

      allPackages = mapAttrs buildPkg options.discovered;
    in
    {
      packages = allPackages;
      filteredPackages = filterPlatforms system allPackages;
    };
}
