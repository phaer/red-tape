# red-tape/contrib — Collect and merge contributions from contrib submodules
#
# Dynamically wired by mkFlake: each contrib module the user passes becomes
# a submodule whose result is consumed here. Core modules (scan, hosts,
# modules) read the aggregated result via inputs.
let
  inherit (builtins)
    attrValues
    concatLists
    foldl'
    map
    ;
in
{
  name = "contrib";
  # inputs are wired dynamically by mkFlake — empty by default (no contribs)
  impl =
    { results, ... }:
    let
      contribs = attrValues results;
    in
    {
      scanHostTypes = concatLists (map (c: c.scanHostTypes or [ ]) contribs);
      hostTypes = foldl' (a: c: a // (c.hostTypes or { })) { } contribs;
      moduleTypes = foldl' (a: c: a // (c.moduleTypes or { })) { } contribs;
    };
}
