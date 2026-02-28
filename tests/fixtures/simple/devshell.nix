{ pkgs, ... }:
pkgs.mkShell {
  packages = [ pkgs.hello ];
}
