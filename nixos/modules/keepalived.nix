{ config, pkgs, ... }:

{
  # Autoriser le bind sur une VIP non locale
  boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

  services.keepalived = {
    enable = true;

    vrrpInstances.VI_1 = {
      interface       = "vlan200";
      state           = "MASTER";
      virtualRouterId = 51;
      priority        = 200;


      virtualIps = [
        {
          addr = "192.168.200.60/24";
        }
      ];


    };
  };
}