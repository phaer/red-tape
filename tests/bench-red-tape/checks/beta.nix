{ pkgs, pname, ... }:
pkgs.runCommand pname {} "touch $out"
