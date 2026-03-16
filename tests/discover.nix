# Tests for per-type scanning patterns (matching what modules do)
let
  discover = import ../lib/discover.nix;
  inherit (discover)
    scanDir
    scanHosts
    coreHostTypes
    scanEntries
    ;
  inherit (builtins) attrNames pathExists readDir filter;

  sort = builtins.sort builtins.lessThan;

  fixtures = ../tests/fixtures;

  # Per-type scanning — mirrors what each module does internally
  scanPackages = src: scanEntries { dir = src + "/packages"; single = src + "/package.nix"; };
  scanDevshells = src: scanEntries { dir = src + "/devshells"; single = src + "/devshell.nix"; };
  scanChecks = src: scanEntries { dir = src + "/checks"; };

  scanFormatter =
    src:
    let
      p = src + "/formatter.nix";
    in
    if pathExists p then p else null;

  scanModules =
    src:
    let
      p = src + "/modules";
    in
    if !pathExists p then
      { }
    else
      let
        e = readDir p;
      in
      builtins.listToAttrs (
        builtins.map (n: {
          name = n;
          value = scanDir (p + "/${n}");
        }) (filter (n: e.${n} == "directory") (attrNames e))
      );

  scanTemplates =
    src:
    let
      p = src + "/templates";
    in
    if !pathExists p then
      { }
    else
      let
        e = readDir p;
      in
      builtins.listToAttrs (
        builtins.map (n: {
          name = n;
          value = {
            path = p + "/${n}";
          };
        }) (filter (n: e.${n} == "directory") (attrNames e))
      );

  scanLib =
    src:
    let
      p = src + "/lib/default.nix";
    in
    if pathExists p then p else null;

  full = fixtures + "/full";
  minimal = fixtures + "/minimal";
  empty = fixtures + "/empty";
in
{
  # --- Full fixture ---

  testFullPackages.expr = sort (attrNames (scanPackages full));
  testFullPackages.expected = [
    "goodbye"
    "hello"
  ];

  testFullDevshells.expr = sort (attrNames (scanDevshells full));
  testFullDevshells.expected = [
    "backend"
    "default"
  ];

  testFullChecks.expr = attrNames (scanChecks full);
  testFullChecks.expected = [ "mycheck" ];

  testFullFormatter.expr = (scanFormatter full) != null;
  testFullFormatter.expected = true;

  testFullHosts.expr = sort (attrNames (scanHosts (full + "/hosts") coreHostTypes));
  testFullHosts.expected = [
    "custom"
    "db"
    "monitoring"
    "myhost"
    "mymac"
  ];

  testFullHostTypes = {
    expr =
      let
        h = scanHosts (full + "/hosts") coreHostTypes;
      in
      {
        myhost = h.myhost.type;
        mymac = h.mymac.type;
        custom = h.custom.type;
      };
    expected = {
      myhost = "nixos";
      mymac = "custom";
      custom = "custom";
    };
  };

  testFullModuleTypes.expr = sort (attrNames (scanModules full));
  testFullModuleTypes.expected = [
    "darwin"
    "home"
    "nixos"
  ];

  testFullNixosModules.expr = sort (attrNames (scanModules full).nixos);
  testFullNixosModules.expected = [
    "injected"
    "server"
  ];

  testFullHomeModules.expr = attrNames (scanModules full).home;
  testFullHomeModules.expected = [ "shared" ];

  testFullTemplates.expr = sort (attrNames (scanTemplates full));
  testFullTemplates.expected = [
    "default"
    "minimal"
  ];

  testFullLib.expr = (scanLib full) != null;
  testFullLib.expected = true;

  # --- Minimal fixture ---

  testMinimalPackage.expr = attrNames (scanPackages minimal);
  testMinimalPackage.expected = [ "default" ];

  testMinimalNoFormatter.expr = scanFormatter minimal;
  testMinimalNoFormatter.expected = null;

  # --- Empty fixture ---

  testEmpty = {
    expr = {
      packages = scanPackages empty;
      devshells = scanDevshells empty;
      checks = scanChecks empty;
      hosts = scanHosts (empty + "/hosts") coreHostTypes;
      modules = scanModules empty;
      formatter = scanFormatter empty;
      templates = scanTemplates empty;
    };
    expected = {
      packages = { };
      devshells = { };
      checks = { };
      hosts = { };
      modules = { };
      formatter = null;
      templates = { };
    };
  };

  # --- Prefixed fixture ---

  testPrefixedPackages.expr = sort (attrNames (scanPackages (fixtures + "/prefixed/nix")));
  testPrefixedPackages.expected = [
    "default"
    "widget"
  ];
}
