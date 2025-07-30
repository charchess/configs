{ config, pkgs, lib, ... }:

let
  fsid = "d3611e34-d36a-45f8-9f86-0f10e5aefb5b";
  hostname = config.networking.hostName;
in
{
  services.ceph = {
    global = {
      inherit fsid;
      monInitialMembers = "jade,emy,ruby";
      monHost = "192.168.111.63,192.168.111.65,192.168.111.66";
      publicNetwork = "192.168.111.0/24";
      clusterNetwork = "192.168.111.0/24";
    };

    mon = {
      enable = true;
      daemons = [ hostname ];
    };
  };
}