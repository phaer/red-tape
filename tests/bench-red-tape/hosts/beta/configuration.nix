{ config, lib, pkgs, hostName, ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = hostName;
  boot.loader.grub.device = "/dev/sda";
  fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

  environment.systemPackages = with pkgs; [
    vim wget curl git htop tmux
  ];

  services.openssh.enable = true;
  services.nginx = {
    enable = true;
    virtualHosts."${hostName}.example.com" = {
      root = "/var/www/${hostName}";
    };
  };

  users.users.deploy = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
  };

  networking.firewall.allowedTCPPorts = [ 22 80 443 ];
  system.stateVersion = "24.11";
}
