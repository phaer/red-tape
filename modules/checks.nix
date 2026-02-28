# /checks — Per-system check assembler
#
# Only handles user-defined checks from the checks/ directory.
# Auto-checks from packages and devshells are assembled by the entry point.

{ types, ... }:
let
  inherit (builtins) mapAttrs intersectAttrs functionArgs;

  filterPlatforms = import ../lib/filter-platforms.nix;
in
{
  name = "checks";

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

      callFile = path: extraArgs:
        let
          fn = import path;
          args = functionArgs fn;
          allArgs = baseScope // extraArgs;
        in
        fn (intersectAttrs args allArgs);

      userChecks = filterPlatforms system (mapAttrs (pname: entry:
        let
          path = if entry.type == "directory" then entry.path + "/default.nix" else entry.path;
        in
        callFile path { inherit pname; }
      ) options.discovered);
    in
    {
      checks = userChecks;
    };
}
