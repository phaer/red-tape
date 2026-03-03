# red-tape flake-level outputs — system-agnostic discovery
#
# Usage:
#   flake = red-tape.lib.flakeOutputs { src = self; inherit inputs; };
#
# Discovers hosts/, modules/, overlays/, templates/, lib/ and returns
# the system-agnostic flake outputs as an attrset.
{ discover, buildAll, buildModules, buildHosts }:

{
  src,
  inputs ? {},
  self ? null,
  prefix ? null,
  moduleTypeAliases ? {},
}:
let
  inherit (builtins)
    attrNames isAttrs isFunction isPath mapAttrs pathExists;

  allInputs = (builtins.removeAttrs inputs [ "self" ])
    // (if self != null then { inherit self; } else {});

  resolvedSrc =
    if prefix != null then
      (if isPath prefix then prefix else src + "/${prefix}")
    else src;

  found = discover.discoverAll resolvedSrc;

  agnostic = { flake = self; inputs = allInputs; };

  hosts = if found.hosts != {} then buildHosts { discovered = found.hosts; inherit allInputs self; } else {};

  result =
    (if found.overlays != {} then { overlays = buildAll agnostic found.overlays; } else {})
    // (builtins.removeAttrs hosts [ "autoChecks" ])
    // (if found.modules != {} then buildModules {
        discovered = found.modules; inherit allInputs self;
        extraTypeAliases = moduleTypeAliases;
      } else {})
    // (let t = mapAttrs (name: e: { inherit (e) path; description =
          let f = e.path + "/flake.nix"; in if pathExists f then (import f).description or name else name;
        }) found.templates; in if t != {} then { templates = t; } else {})
    // (let l = if found.lib == null then {} else let m = import found.lib;
          in if isFunction m then m { flake = self; inputs = allInputs; } else m;
        in if l != {} then { lib = l; } else {});
in
  result
