# /etc/nixos/common/ceph-firewall.nix
{ config, pkgs, ... }:

let
  # Plage Ceph classique : 6800-7300 TCP/UDP
  cephPortRange = { from = 6800; to = 7300; };
in
{
  networking.firewall = {
    enable = true;
    allowedTCPPortRanges = [ cephPortRange ];
    allowedUDPPortRanges = [ cephPortRange ];

    # Ports fixes supplémentaires
    allowedTCPPorts = [
      6789  # ceph-mon (v1)
      3300  # ceph-mon (v2)
      7480  # radosgw (si activé)
    ];
  };
}


