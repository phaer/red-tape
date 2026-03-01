{ pkgs, ... }:
pkgs.mkShell { packages = [ pkgs.hello pkgs.curl ]; }
