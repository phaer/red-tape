# red-tape — Convention-based Nix project builder on adios-flake
{ adios-flake }:
let
  adiosFlakeLib = adios-flake.lib or adios-flake;
  defaultModules = import ../modules;

  # Build the red-tape root module with contrib submodules dynamically wired.
  # Each contrib module becomes a child of the contrib collector, which
  # aggregates their results for project/hosts/modules to consume via inputs.
  mkRootModule =
    contribs:
    let
      base = defaultModules.redTape.default;
      contribMod = base.modules.contrib;
      # Wire each contrib as a submodule with an input in the collector
      numberedContribs = builtins.genList (i: {
        name = "_c${toString i}";
        value = builtins.removeAttrs (builtins.elemAt contribs i) [ "name" ];
      }) (builtins.length contribs);
      contribChildren = builtins.listToAttrs numberedContribs;
      contribInputs = builtins.listToAttrs (
        map (c: {
          inherit (c) name;
          value = {
            path = "./${c.name}";
          };
        }) numberedContribs
      );
    in
    base
    // {
      modules = base.modules // {
        contrib = contribMod // {
          inputs = contribMod.inputs or { } // contribInputs;
          modules = (contribMod.modules or { }) // contribChildren;
        };
      };
    };

  isContrib = m: builtins.isAttrs m && m ? impl;

  mkFlake =
    {
      inputs,
      self ? null,
      src,
      prefix ? null,
      systems ? [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ],
      modules ? [ ],
      perSystem ? null,
      config ? { },
      flake ? { },
    }:
    let
      contribs = builtins.filter isContrib modules;
      passthrough = builtins.filter (m: !isContrib m) modules;
    in
    adiosFlakeLib.mkFlake {
      inherit
        inputs
        self
        systems
        perSystem
        flake
        ;
      modules = [ (mkRootModule contribs) ] ++ passthrough;
      config = {
        "red-tape/project" = {
          inherit src self systems;
          inputs = inputs;
        }
        // (if prefix != null then { inherit prefix; } else { });
      }
      // config;
    };
in
{
  inherit mkFlake;
  modules = defaultModules;
}
