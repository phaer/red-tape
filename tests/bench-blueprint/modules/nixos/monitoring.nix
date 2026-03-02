{ config, lib, pkgs, ... }:
let
  cfg = config.services.bench-monitoring;
in {
  options.services.bench-monitoring = {
    enable = lib.mkEnableOption "bench monitoring service";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hello;
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
