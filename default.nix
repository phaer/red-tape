# red-tape — Traditional (non-flake) entry point
#
# Usage:
#   import ./. { }                          # uses npins defaults
#   import ./. { pkgs = import <nixpkgs> {}; }  # custom nixpkgs
#
# For red-tape consumers (projects using red-tape):
#   let red-tape = import sources.red-tape;
#   in red-tape.eval { inherit pkgs; src = ./.; }
{
  __sources ? import ./npins,
  pkgs ? import __sources.nixpkgs { },
  adios ? (import __sources.adios).adios,
}:
let
  redTape = import ./lib/mk-red-tape.nix { inherit adios; };

  # red-tape's own development outputs
  selfResult = redTape.eval {
    inherit pkgs;
    src = ./.;
  };

  shell = pkgs.mkShell {
    packages = [
      pkgs.npins
      pkgs.nix-unit
    ] ++ (if selfResult.formatter != null then [ selfResult.formatter ] else []);
  };
in
{
  inherit shell;

  # Export for consumers
  inherit (redTape) mkFlake eval;
}
