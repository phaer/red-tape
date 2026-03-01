let
  sources = import ./npins;
  pkgs = import sources.nixpkgs {};
in
pkgs.mkShell {
  packages = [
    pkgs.npins
    pkgs.nixfmt-tree
    pkgs.nix-unit
  ];
}
