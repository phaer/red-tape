# red-tape/modules — Discover and export NixOS/Darwin/Home modules
let
  inherit (import ../lib/utils.nix) entryPath;
  inherit (import ../lib/discover.nix) scanDir;
  inherit (builtins)
    all
    attrNames
    elem
    filter
    foldl'
    functionArgs
    intersectAttrs
    isFunction
    listToAttrs
    mapAttrs
    pathExists
    readDir
    ;

  defaultModuleTypes = {
    nixos = "nixosModules";
  };

  buildModules =
    {
      discovered,
      inputs,
      self,
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
in
{
  name = "modules";
  inputs = {
    scan = {
      path = "../scan";
    };
    contrib = {
      path = "../contrib";
    };
  };

  impl =
    { results, ... }:
    let
      src = results.scan.resolvedSrc;
      inherit (results.scan) self inputs;
      p = src + "/modules";
      discovered =
        if !pathExists p then
          { }
        else
          let
            e = readDir p;
          in
          listToAttrs (
            builtins.map (n: {
              name = n;
              value = scanDir (p + "/${n}");
            }) (filter (n: e.${n} == "directory") (attrNames e))
          );
    in
    if discovered != { } then
      buildModules {
        inherit discovered inputs self;
        extraModuleTypes = results.contrib.moduleTypes;
      }
    else
      { };
}
