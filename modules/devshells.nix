# /devshells — Per-system devshell builder
#
# Each .nix file receives: { pkgs, system, pname, lib, ... }

{ types, ... }:
let
  inherit (builtins) mapAttrs intersectAttrs functionArgs;
in
{
  name = "devshells";

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
      pkgs = inputs.nixpkgs.pkgs;
      system = inputs.nixpkgs.system;

      baseScope = {
        inherit pkgs system;
        lib = pkgs.lib;
      } // options.extraScope;

      callFile = path: extraArgs:
        let
          fn = import path;
          args = functionArgs fn;
          allArgs = baseScope // extraArgs;
        in
        fn (intersectAttrs args allArgs);

      buildShell = pname: entry:
        let
          path = if entry.type == "directory" then entry.path + "/default.nix" else entry.path;
        in
        callFile path { inherit pname; };
    in
    {
      devShells = mapAttrs buildShell options.discovered;
    };
}
