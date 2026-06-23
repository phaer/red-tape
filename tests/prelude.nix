# Test prelude — shared setup for all test files
let
  discover = import ../lib/internal.nix;

  lib = { };

  mockPkgs = {
    system = "x86_64-linux";
    inherit lib;
    mkShell = args: { type = "devshell"; } // args;
    hello = {
      type = "derivation";
      name = "hello";
      meta = { };
    };
    jq = {
      type = "derivation";
      name = "jq";
      meta = { };
    };
    writeShellScriptBin = name: text: {
      type = "derivation";
      inherit name;
      meta = { };
    };
    runCommand = name: env: cmd: {
      type = "derivation";
      inherit name;
      meta = { };
    };
    nodejs = {
      type = "derivation";
      name = "nodejs";
      meta = { };
    };
    nixfmt-tree = {
      type = "derivation";
      name = "nixfmt-tree";
      meta = { };
    };
  };

  sys = "x86_64-linux";
  fixtures = ../tests/fixtures;

  helpers = import ../lib/internal.nix;

  # Domain builders — extracted for direct testing without adios runtime
  inherit (builtins)
    addErrorContext
    all
    attrNames
    elem
    filter
    foldl'
    functionArgs
    intersectAttrs
    isAttrs
    isFunction
    listToAttrs
    map
    mapAttrs
    ;
  inherit (helpers) entryPath coreHostTypes;

  # Thin shim over the real lib/internal.nix buildHosts: fills test-only
  # defaults (flake context + a stub pkgsFor) so call sites stay terse while
  # exercising the real build logic.
  buildHosts =
    {
      discovered,
      inputs ? { },
      self ? null,
      defaultSystem ? sys,
      pkgsFor ? (
        system: {
          _type = "pkgs";
          inherit system;
        }
      ),
      extraHostTypes ? { },
    }:
    helpers.buildHosts {
      inherit
        discovered
        inputs
        self
        defaultSystem
        pkgsFor
        extraHostTypes
        ;
    };

  defaultModuleTypes = {
    nixos = "nixosModules";
  };

  buildModules =
    {
      discovered,
      inputs ? { },
      self ? null,
      extraModuleTypes ? { },
    }:
    let
      publisherArgs = {
        flake = self;
        inherit inputs;
      };
      moduleTypes = defaultModuleTypes // extraModuleTypes;
      isPublisherFn =
        fn:
        isFunction fn
        && (functionArgs fn) != { }
        && all (
          a:
          elem a [
            "flake"
            "inputs"
          ]
        ) (attrNames (functionArgs fn));
      importModule =
        e:
        let
          path = entryPath e;
          mod = import path;
        in
        if isPublisherFn mod then
          {
            _file = toString path;
            imports = [ (mod (intersectAttrs (functionArgs mod) publisherArgs)) ];
          }
        else
          path;
      built = mapAttrs (_: mapAttrs (_: importModule)) discovered;

      aliased = foldl' (
        acc: t:
        let
          alias = moduleTypes.${t} or null;
        in
        if alias != null then acc // { ${alias} = built.${t}; } else acc
      ) { } (attrNames discovered);
    in
    aliased // (if built != { } then { modules = built; } else { });

  builders = { inherit buildHosts buildModules; };
in
{
  inherit
    mockPkgs
    sys
    fixtures
    discover
    helpers
    builders
    coreHostTypes
    ;
}
