{ config, lib, pkgs, ... }:
let
  cfg = config.services.bench-backup;
in {
  options.services.bench-backup = {
    enable = lib.mkEnableOption "bench backup service";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hello;
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
