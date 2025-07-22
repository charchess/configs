{ config, pkgs, ... }:

{
  # configuration de keepalived
  boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

#  services.keepalived = {
#    enable = true;
#
#    # Définition de votre instance VRRP nommée "VI_1"
#    vrrpInstances.VI_1 = {
#      # Assurez-vous que le nom de l'interface 'vlan200' est correct sur votre système.
#      # D'après votre configuration précédente, l'interface s'appelle 'vlan200'.
#      interface = "vlan200"; 
#      
#      state = "BACKUP";
#      virtualRouterId = 51;
#      priority = 100;
#
#      # La liste des adresses IP virtuelles à gérer
#      virtualIps.netlink.addr = [
#        "192.168.200.60/24"
#      ];
#      
#    };
#  };
}