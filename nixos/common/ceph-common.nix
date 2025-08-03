# /etc/nixos/common/ceph-common.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ../modules/ceph-base.nix
    ../modules/ceph-mon.nix
    ../modules/ceph-osd.nix
    ../modules/ceph-mgr.nix
  ];

  # Common Ceph cluster settings
  services.ceph-cluster = {
    enable = true;
    clusterName = "nixos-ceph";
    # IMPORTANT: Replace with your actual cluster FSID
    # You can generate one with `uuidgen`
    fsid = "a9a18ab9-57cf-4841-8b22-1a1de12961d0";
    publicNetwork = "192.168.111.0/24"; # All nodes are on this network
    clusterNetwork = "192.168.111.0/24"; # Using the same network for simplicity

    monitors = {
      jade = {
        enable = true;
        initial = true;
        address = "192.168.111.63";
      };
      emy = {
        enable = true;
        initial = true;
        address = "192.168.111.65";
      };
      ruby = {
        enable = true;
        initial = true;
        address = "192.168.111.66";
      };
    };

    osds = {
      "0" = {
        host = "jade";
        device = "/dev/sdb";
      };
      "1" = {
        host = "emy";
        device = "/dev/sda";
      };
      "2" = {
        host = "ruby";
        device = "/dev/sdc";
      };
    };

    mgrs = {
      jade = {
        enable = true;
        host = "jade";
      };
      emy = {
        enable = true;
        host = "emy";
      };
    };

    keys = {
      adminKeyring = ''
        [client.admin]
        	key = AQBH74poVUgWHBAAD9B4hZSEZe3b+brAJLDgTQ==
        	caps mgr = "allow *"
        	caps mon = "allow *"
        	caps osd = "allow *"
      '';
      monKeyring = ''
        [mon.]
        	key = AQBH74po3QrcGRAA+ck/YzNo7wDu31qB4eqzBA==
        	caps mon = "allow *"
        [client.admin]
        	key = AQBH74poVUgWHBAAD9B4hZSEZe3b+brAJLDgTQ==
        	caps mgr = "allow *"
        	caps mon = "allow *"
        	caps osd = "allow *"
      '';
    };
  };
}
