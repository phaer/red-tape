{ config, lib, pkgs, ... }:
let
  cfg = config.services.bench-firewall;
in {
  options.services.bench-firewall = {
    enable = lib.mkEnableOption "bench firewall service";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hello;
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
