{ config, pkgs, ... }:

{
  # Autoriser le bind sur une VIP non locale
  boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

  services.keepalived = {
    enable = true;

    vrrpInstances.VI_1 = {
      interface       = "ens33";
      state           = "MASTER";
      virtualRouterId = 51;
      priority        = 200;


      virtualIps = [
        {
          addr = "192.168.200.60/24"; # <-- L'attribut correct est `addr`
          dev = "enp1s0.200";             # <-- L'attribut correct est `dev`
        }
      ];


    };
  };
}