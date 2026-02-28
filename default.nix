# red-tape — Traditional (non-flake) entry point
#
# For red-tape consumers:
#   let red-tape = import sources.red-tape;
#   in red-tape.eval { inherit pkgs; src = ./.; }
{
  __sources ? import ./npins,
  adios ? (import __sources.adios).adios,
}:
import ./lib/mk-red-tape.nix { inherit adios; }
