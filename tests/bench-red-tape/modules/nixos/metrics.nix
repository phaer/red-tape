{ config, lib, pkgs, ... }:
let
  cfg = config.services.bench-metrics;
in {
  options.services.bench-metrics = {
    enable = lib.mkEnableOption "bench metrics service";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hello;
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
