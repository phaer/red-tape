# /overlays — Per-system overlay builder
#
# Each .nix file should return a nixpkgs overlay (final: prev: { ... }).
# Files receive the standard callPackage scope: { pkgs, system, pname, lib, ... }

{ types, ... }:
let
  inherit (builtins) mapAttrs;

  callFile = import ../lib/call-file.nix;
in
{
  name = "overlays";

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
      scope = {
        pkgs = inputs.nixpkgs.pkgs;
        system = inputs.nixpkgs.system;
        lib = inputs.nixpkgs.pkgs.lib;
      } // options.extraScope;

      buildOverlay = pname: entry:
        let path = if entry.type == "directory" then entry.path + "/default.nix" else entry.path;
        in callFile scope path { inherit pname; };
    in
    {
      overlays = mapAttrs buildOverlay options.discovered;
    };
}
