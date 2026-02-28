# /formatter — Per-system formatter
#
# Imports formatter.nix if discovered, otherwise falls back to nixfmt-tree.

{ types, ... }:
let
  inherit (builtins) intersectAttrs functionArgs;
in
{
  name = "formatter";

  inputs = {
    nixpkgs = { path = "/nixpkgs"; };
  };

  options = {
    # null if no formatter.nix was discovered
    formatterPath = {
      type = types.any;
      default = null;
    };
    extraScope = {
      type = types.attrs;
      default = {};
    };
  };

  impl = { inputs, options, ... }:
    let
      pkgs = inputs.nixpkgs.pkgs;

      baseScope = {
        inherit pkgs;
        system = inputs.nixpkgs.system;
        lib = pkgs.lib;
      } // options.extraScope;

      callFile = path:
        let
          fn = import path;
          args = functionArgs fn;
        in
        fn (intersectAttrs args baseScope);
    in
    {
      formatter =
        if options.formatterPath != null then
          callFile options.formatterPath
        else
          pkgs.nixfmt-tree or pkgs.nixfmt or
            (throw "red-tape: no formatter.nix found and nixfmt-tree is not available in nixpkgs");
    };
}
