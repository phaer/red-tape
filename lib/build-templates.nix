# build-templates.nix — Export discovered templates
#
# Returns: { name = { path, description }; ... }
# Description is read from the template's flake.nix if present.

discoveredTemplates:
let
  inherit (builtins) mapAttrs pathExists;
in
mapAttrs (name: entry:
  let
    flakeNix = entry.path + "/flake.nix";
    description =
      if pathExists flakeNix then
        (import flakeNix).description or name
      else
        name;
  in
  {
    inherit (entry) path;
    inherit description;
  }
) discoveredTemplates
