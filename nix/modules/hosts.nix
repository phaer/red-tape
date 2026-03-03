# red-tape/hosts — Build NixOS/Darwin host configurations
#
# Inputs: ../scan
# Options: self, inputs
# Result: { nixosConfigurations, darwinConfigurations, autoChecks }
#
# autoChecks is a function system → { name = toplevel; } consumed by ../checks.
# nixosConfigurations and darwinConfigurations are flake-scoped.
{ buildHosts }:

{
  name = "hosts";
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
  };
  impl = { results, options, ... }:
    let
      inherit (builtins) removeAttrs;
      found = results.scan;
      self = options.self;
      allInputs = (removeAttrs options.inputs [ "self" ])
        // (if self != null then { inherit self; } else {});
    in
    if found.hosts != {} then
      buildHosts { discovered = found.hosts; inherit allInputs self; }
    else
      { nixosConfigurations = {}; darwinConfigurations = {}; autoChecks = _: {}; };
}
