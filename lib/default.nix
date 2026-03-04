# red-tape — Convention-based Nix project builder on adios-flake
{ adios-flake }:
let
  adiosFlakeLib = adios-flake.lib or adios-flake;
  defaultModules = import ../modules;

  strip = m: builtins.removeAttrs m [ "name" ];

  # Build the red-tape root module with contrib submodules dynamically wired.
  # Each contrib module becomes a child of the contrib collector, which
  # aggregates their results for scan/hosts/modules to consume via inputs.
  mkRootModule =
    contribs:
    let
      base = defaultModules.redTape.default;
      contribMod = base.modules.contrib;
      # Wire each contrib as a submodule with an input in the collector
      numberedContribs = builtins.genList (i: {
        name = "_c${toString i}";
        value = strip (builtins.elemAt contribs i);
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
    adiosFlakeLib.mkFlake {
      inherit
        inputs
        self
        systems
        perSystem
        flake
        ;
      modules = [ (mkRootModule modules) ];
      config = {
        "red-tape/scan" = {
          inherit src self;
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
