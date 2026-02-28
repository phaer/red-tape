# /modules-export — System-agnostic module re-export
#
# No /nixpkgs dependency — just re-exports paths or injects publisher args.
# Evaluated once by adios, memoized across system overrides.
#
# Well-known type aliases:
#   modules/nixos/  → nixosModules
#   modules/darwin/ → darwinModules
#   modules/home/   → homeModules

{ types, ... }:
let
  inherit (builtins)
    all
    attrNames
    elem
    foldl'
    functionArgs
    intersectAttrs
    isFunction
    mapAttrs
    ;

  typeAliases = {
    nixos = "nixosModules";
    darwin = "darwinModules";
    home = "homeModules";
  };
in
{
  name = "modules-export";

  # No inputs — system-independent

  options = {
    discovered = {
      type = types.attrs;
      default = {};
    };
    flakeInputs = {
      type = types.attrs;
      default = {};
    };
    self = {
      type = types.any;
      default = null;
    };
  };

  impl = { options, ... }:
    let
      flakeInputs = options.flakeInputs;
      self = options.self;
      allInputs = flakeInputs // (if self != null then { self = self; } else {});

      publisherArgs = {
        flake = self;
        inputs = allInputs;
      };

      # Must have at least one named arg matching publisher args
      # (excludes { ... }: catch-all which would be a NixOS module)
      expectsPublisherArgs = fn:
        let args = functionArgs fn;
        in isFunction fn
        && args != {}
        && all (arg: elem arg (attrNames publisherArgs))
          (attrNames args);

      importModule = entry:
        let
          path = if entry.type == "directory" then entry.path + "/default.nix" else entry.path;
          mod = import path;
        in
        if expectsPublisherArgs mod then
          mod (intersectAttrs (functionArgs mod) publisherArgs)
        else
          path;

      allModules = mapAttrs (_type: entries:
        mapAttrs (_name: importModule) entries
      ) options.discovered;

      aliases = foldl' (acc: typeName:
        let alias = typeAliases.${typeName} or null;
        in if alias != null && options.discovered ? ${typeName}
           then acc // { ${alias} = allModules.${typeName}; }
           else acc
      ) {} (attrNames options.discovered);
    in
    aliases;
}
