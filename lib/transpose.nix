# transpose.nix — Transpose per-system results to flake output shape
#
# Input:  { system → { category → { name → value } } }
# Output: { category → { system → { name → value } } }
#
# Handles categories that appear in only a subset of systems.

let
  inherit (builtins)
    attrNames
    elem
    foldl'
    filter
    listToAttrs
    map
    ;

  transpose = perSystemResults:
    let
      systems = attrNames perSystemResults;

      # Collect all categories across all systems
      allCategories = foldl' (acc: sys:
        let cats = attrNames perSystemResults.${sys};
        in acc ++ (filter (c: !elem c acc) cats)
      ) [] systems;
    in
    listToAttrs (map (cat: {
      name = cat;
      value = listToAttrs (map (sys: {
        name = sys;
        value = perSystemResults.${sys}.${cat} or {};
      }) systems);
    }) allCategories);

in
transpose
