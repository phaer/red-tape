{ config, lib, pkgs, ... }:
let
  cfg = config.services.bench-logging;
in {
  options.services.bench-logging = {
    enable = lib.mkEnableOption "bench logging service";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hello;
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
