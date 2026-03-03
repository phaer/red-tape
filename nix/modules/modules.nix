# red-tape/modules — Discover and export NixOS/Darwin/Home modules
#
# Inputs: ../scan
# Options: self, inputs, moduleTypeAliases
# Result: { nixosModules, darwinModules, homeModules, ... }
{ buildModules }:

{
  name = "modules";
  inputs = {
    scan = { path = "../scan"; };
  };
  options = {
    self = {
      type = { name = "any"; verify = _: null; };
      default = null;
    };
    inputs = {
      type = { name = "attrs"; verify = v: if builtins.isAttrs v then null else "expected attrset"; };
      default = {};
    };
    moduleTypeAliases = {
      type = { name = "attrs"; verify = v: if builtins.isAttrs v then null else "expected attrset"; };
      default = {};
    };
  };
  impl = { results, options, ... }:
    let
      inherit (builtins) removeAttrs;
      found = results.scan;
      self = options.self;
      allInputs = (removeAttrs options.inputs [ "self" ])
        // (if self != null then { inherit self; } else {});
    in
    if found.modules != {} then
      buildModules {
        discovered = found.modules;
        inherit allInputs self;
        extraTypeAliases = options.moduleTypeAliases;
      }
    else
      {};
}
