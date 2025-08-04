{ config, lib, pkgs, ... }:

{
  # Enable Ceph packages
  environment.systemPackages = with pkgs; [
    ceph
    ceph-client
  ];

  # Create ceph user and group
  users.users.ceph = {
    isSystemUser = true;
    group = "ceph";
    home = "/var/lib/ceph";
    createHome = true;
  };

  users.groups.ceph = {};

  # Ensure directories exist
  systemd.tmpfiles.rules = [
    "d /var/lib/ceph 0755 ceph ceph -"
    "d /var/lib/ceph/mon 0755 ceph ceph -"
    "d /var/lib/ceph/mgr 0755 ceph ceph -"
    "d /var/lib/ceph/osd 0755 ceph ceph -"
    "d /var/lib/ceph/mds 0755 ceph ceph -"
    "d /var/lib/ceph/tmp 0755 ceph ceph -"
    "d /etc/ceph 0755 ceph ceph -"
  ];

  # Ceph configuration file
  environment.etc."ceph/ceph.conf".text = ''
[global]
fsid = 3371b0d9-2f6f-4223-bbba-3118c4a30681
mon_initial_members = grenat,jade
mon_host = 192.168.111.64,192.168.111.63
public_network = 192.168.111.0/24
cluster_network = 192.168.111.0/24
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx
osd_pool_default_size = 1
osd_pool_default_min_size = 1
osd_pool_default_pg_num = 8
osd_pool_default_pgp_num = 8
mon_allow_pool_delete = true

[mon.jade]
host = jade
mon_addr = 192.168.111.63

[mgr.jade]
host = jade
'';

  # Ceph Monitor service
  systemd.services.ceph-mon = {
    description = "Ceph Monitor";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "forking";
      User = "ceph";
      Group = "ceph";
      ExecStart = "${pkgs.ceph}/bin/ceph-mon --cluster ceph --id jade --public-addr 192.168.111.63";
      ExecReload = "${pkgs.ceph}/bin/ceph-mon --cluster ceph --id jade --public-addr 192.168.111.63 --reload";
      Restart = "always";
      RestartSec = 10;
    };
  };

  # Ceph Manager service
  systemd.services.ceph-mgr = {
    description = "Ceph Manager";
    after = [ "network.target" "ceph-mon.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "forking";
      User = "ceph";
      Group = "ceph";
      ExecStart = "${pkgs.ceph}/bin/ceph-mgr --cluster ceph --id jade";
      ExecReload = "${pkgs.ceph}/bin/ceph-mgr --cluster ceph --id jade --reload";
      Restart = "always";
      RestartSec = 10;
    };
  };
}
