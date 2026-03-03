# red-tape/scan — Pure filesystem discovery + shared flake context
#
# Options:
#   src            — Source path to scan (typically `self`)
#   prefix         — Optional subdirectory prefix
#   self           — The flake self (path-like, for threading as `flake` into user exprs)
#   inputs         — All flake inputs
#   extraHostTypes — Extra host sentinel descriptors appended to coreHostTypes
#                    e.g. [ { type = "nix-on-droid"; file = "droid-configuration.nix"; } ]
#
# Result: { discovered, src, self, allInputs }
#   discovered — the full discoverAll attrset
#   src        — resolved source path
#   self       — flake self (as-is)
#   allInputs  — inputs with self merged in
{ discover }:

let
  inherit (builtins) isPath isList removeAttrs;
in
{
  name = "scan";
  options = {
    src = {
      type = {
        name = "path-like";
        verify = v:
          if isPath v || builtins.isString v
          then null
          else "expected a path or string";
      };
    };
    prefix = {
      type = {
        name = "nullable-string";
        verify = v:
          if v == null || builtins.isString v || isPath v
          then null
          else "expected null, a string, or a path";
      };
      default = null;
    };
    self = {
      # Never inspected — avoids forcing the flake fixpoint to WHNF.
      type = { name = "any"; verify = _: null; };
      default = null;
    };
    inputs = {
      type = { name = "attrs"; verify = v: if builtins.isAttrs v then null else "expected attrset"; };
      default = {};
    };
    extraHostTypes = {
      type = { name = "list"; verify = v: if isList v then null else "expected a list"; };
      default = [];
    };
  };
  impl = { options, ... }:
    let
      src = options.src;
      prefix = options.prefix;
      self = options.self;
      resolvedSrc =
        if prefix != null then
          (if isPath prefix then prefix else src + "/${prefix}")
        else src;
      allInputs = (removeAttrs options.inputs [ "self" ])
        // (if self != null then { inherit self; } else {});
      hostTypes = discover.coreHostTypes ++ options.extraHostTypes;
    in
    {
      discovered = discover.discoverAll resolvedSrc // {
        hosts = discover.scanHosts (resolvedSrc + "/hosts") hostTypes;
      };
      inherit src self allInputs;
    };
}
