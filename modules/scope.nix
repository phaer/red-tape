# red-tape/scope — Shared callPackage-like evaluation scope
#
# Depends on /nixpkgs (system, pkgs) and ../scan (flake context).
# Downstream per-system modules use `scope` instead of duplicating setup.
{
  name = "scope";
  inputs = {
    nixpkgs = {
      path = "/nixpkgs";
    };
    scan = {
      path = "../scan";
    };
  };
  impl =
    { inputs, results, ... }:
    let
      inherit (builtins) isAttrs mapAttrs;
      system = inputs.nixpkgs.system;
      pkgs = inputs.nixpkgs.pkgs;
      flakeInputs = results.scan.inputs;
      self = results.scan.self;
    in
    {
      inherit system pkgs self;
      inputs = flakeInputs;
      scope = {
        inherit system pkgs;
        lib = pkgs.lib;
        flake = self;
        inputs = flakeInputs;
        perSystem = mapAttrs (
          _: i: if isAttrs i then (i.legacyPackages.${system} or { }) // (i.packages.${system} or { }) else i
        ) flakeInputs;
      };
    };
}
