# Tests for the discover function
let
  prelude = import ./prelude.nix;
  inherit (prelude) _internal fixtures;
  inherit (_internal) coreDescriptors;
  discover = src: _internal.discover src coreDescriptors;
in
{
  # --- Packages ---

  testDiscoverPackages = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (discover (fixtures + "/simple")).packages);
    expected = [ "goodbye" "hello" ];
  };

  testDiscoverPackageNix = {
    expr = builtins.attrNames (discover (fixtures + "/minimal")).packages;
    expected = [ "default" ];
  };

  # --- DevShells ---

  testDiscoverDevshells = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (discover (fixtures + "/simple")).devshells);
    expected = [ "backend" "default" ];
  };

  # --- Formatter ---

  testDiscoverFormatter = {
    expr = (discover (fixtures + "/simple")).formatter != null;
    expected = true;
  };

  testNoFormatter = {
    expr = (discover (fixtures + "/minimal")).formatter;
    expected = null;
  };

  # --- Checks ---

  testDiscoverChecks = {
    expr = builtins.attrNames (discover (fixtures + "/simple")).checks;
    expected = [ "mycheck" ];
  };

  # --- Empty ---

  testDiscoverEmpty = {
    expr =
      let result = discover (fixtures + "/empty");
      in {
        hasPackages  = result ? packages;
        hasDevshells = result ? devshells;
        hasChecks    = result ? checks;
        hasHosts     = result ? hosts;
        hasOverlays  = result ? overlays;
        hasModules   = result ? modules-export;
        formatter    = result.formatter;
        templates    = result.templates;
      };
    expected = {
      hasPackages  = false;
      hasDevshells = false;
      hasChecks    = false;
      hasHosts     = false;
      hasOverlays  = false;
      hasModules   = false;
      formatter    = null;
      templates    = {};
    };
  };

  # --- Overlays ---

  testDiscoverOverlays = {
    expr = builtins.attrNames (discover (fixtures + "/simple")).overlays;
    expected = [ "my-overlay" ];
  };

  testDiscoverOverlayNix = {
    expr = builtins.attrNames (discover (fixtures + "/full")).overlays;
    expected = [ "default" ];
  };

  testNoOverlays = {
    expr = (discover (fixtures + "/minimal")) ? overlays;
    expected = false;
  };

  # --- Hosts ---

  testDiscoverHosts = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (discover (fixtures + "/full")).hosts);
    expected = [ "custom" "myhost" "mymac" ];
  };

  testHostConfigTypes = {
    expr =
      let hosts = (discover (fixtures + "/full")).hosts;
      in {
        myhost = hosts.myhost.type;
        mymac = hosts.mymac.type;
        custom = hosts.custom.type;
      };
    expected = {
      myhost = "nixos";
      mymac = "custom";  # default.nix escape hatch
      custom = "custom";
    };
  };

  # --- Modules ---

  testDiscoverModuleTypes = {
    expr =
      let mods = (discover (fixtures + "/full")).modules-export;
      in builtins.sort builtins.lessThan (builtins.attrNames mods);
    expected = [ "darwin" "home" "nixos" ];
  };

  testDiscoverNixosModules = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (discover (fixtures + "/full")).modules-export.nixos);
    expected = [ "injected" "server" ];
  };

  testDiscoverHomeModules = {
    expr = builtins.attrNames (discover (fixtures + "/full")).modules-export.home;
    expected = [ "shared" ];
  };

  # --- Templates ---

  testDiscoverTemplates = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (discover (fixtures + "/full")).templates);
    expected = [ "default" "minimal" ];
  };

  # --- Lib ---

  testDiscoverLib = {
    expr = (discover (fixtures + "/full")).lib != null;
    expected = true;
  };

  testNoLib = {
    expr = (discover (fixtures + "/simple")).lib;
    expected = null;
  };
}
