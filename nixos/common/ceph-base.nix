{ config, pkgs, ... }:

{
  # Users Ceph
  users.users.ceph = {
    isNormalUser = true;
    extraGroups = [ "wheel" "ceph" ];
    home = "/var/lib/ceph";
    createHome = true;
  };
  
  users.groups.ceph = {};

  # Packages nécessaires
  environment.systemPackages = with pkgs; [
    ceph
    ceph-client
    jq
    parted
  ];

  # Paramètres système
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "kernel.pid_max" = 4194303;
  };

  # Services de base
  services.journald.extraConfig = "SystemMaxUse=1G";
}

