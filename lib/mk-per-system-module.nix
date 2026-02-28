# mk-per-system-module.nix — Generic per-system module factory
#
# All per-system modules (packages, devshells, checks) share the same
# pattern: build scope from /nixpkgs + extraScope, mapAttrs discovered
# entries through callFile. This extracts that boilerplate.
#
# postProcess: receives { system, pkgs, built } and returns the module result.

{ name, postProcess ? ({ built, ... }: built) }:

{ types, ... }:
let
  callFile = import ./call-file.nix;
in
{
  inherit name;

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

      scope = {
        inherit pkgs system;
        lib = pkgs.lib;
      } // options.extraScope;

      built = builtins.mapAttrs (pname: entry:
        let path = if entry.type == "directory" then entry.path + "/default.nix" else entry.path;
        in callFile scope path { inherit pname; }
      ) options.discovered;
    in
    postProcess { inherit system pkgs built; };
}
