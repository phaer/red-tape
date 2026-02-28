# filter-platforms.nix — Filter packages by meta.platforms
#
# Keeps packages that either:
# - Have no meta.platforms set (assumed to work everywhere)
# - List the given system in meta.platforms

let
  inherit (builtins) elem filter listToAttrs map attrNames;

  filterPlatforms = system: packages:
    listToAttrs (filter (x: x != null) (map (name:
      let
        pkg = packages.${name};
        platforms = pkg.meta.platforms or [];
      in
      if platforms == [] || elem system platforms then
        { inherit name; value = pkg; }
      else
        null
    ) (attrNames packages)));

in
filterPlatforms
