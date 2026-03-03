# red-tape/scope — Build shared evaluation scope for per-system modules
#
# Inputs: /nixpkgs (system, pkgs)
# Options: self, inputs
# Result: { system, pkgs, lib, scope, allInputs, self }
#
# Downstream per-system modules (packages, devshells, checks, formatter)
# depend on ../scope to get the evaluation scope without duplicating it.
{
  name = "scope";
  inputs = {
    nixpkgs = { path = "/nixpkgs"; };
  };
  options = {
    self = {
      type = { name = "any"; verify = _: null; };
      default = null;
    };
    inputs = {
      type = { name = "attrs"; verify = v: if builtins.isAttrs v then null else "expected attrset"; };
      default = {};
    };
  };
  impl = { inputs, options, ... }:
    let
      inherit (builtins) isAttrs mapAttrs removeAttrs;
      system = inputs.nixpkgs.system;
      pkgs = inputs.nixpkgs.pkgs;
      self = options.self;
      allInputs = (removeAttrs options.inputs [ "self" ])
        // (if self != null then { inherit self; } else {});
    in
    {
      inherit system pkgs self allInputs;
      scope = {
        inherit system pkgs;
        lib = pkgs.lib;
        flake = self;
        inputs = allInputs;
        perSystem = mapAttrs (_: i:
          if isAttrs i then (i.legacyPackages.${system} or {}) // (i.packages.${system} or {}) else i
        ) allInputs;
      };
    };
}
