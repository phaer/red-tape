# contrib/system-manager.nix — system-manager host support as an adios-flake module
#
# Extends red-tape's host scanning and building with system-manager support.
# Scans hosts/ for system-configuration.nix files and produces
# systemConfigs.<hostname> outputs.
#
# Usage:
#   modules = [
#     (import (red-tape + "/contrib/system-manager.nix"))
#   ];

_:
{
  "/red-tape/scan".extraHostTypes = [
    { type = "system-manager"; file = "system-configuration.nix"; }
  ];

  "/red-tape/hosts".extraHostBuilders.system-manager = {
    outputKey = "systemConfigs";
    build = { name, info, specialArgs, allInputs }:
      let sm = allInputs.system-manager
        or (throw "red-tape: system-manager contrib needs inputs.system-manager");
      in builtins.addErrorContext "while building system-manager host '${name}'"
        (sm.lib.makeSystemConfig {
          modules     = [ info.configPath ];
          specialArgs = specialArgs // { hostName = name; };
        });
  };
}
