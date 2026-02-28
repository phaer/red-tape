# /nixpkgs — Data-only module providing system and pkgs to downstream modules.
#
# No impl: this is purely an options container.
# The entry point overrides these per-system.

{ types, ... }:
{
  name = "nixpkgs";
  options = {
    system = {
      type = types.string;
    };
    pkgs = {
      type = types.attrs;
    };
  };
}
