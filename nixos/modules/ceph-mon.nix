{ config, pkgs, lib, ... }:

let
  fsid = "d3611e34-d36a-45f8-9f86-0f10e5aefb5b";
in
{
  services.ceph = {
    global = {
      fsid = fsid;
      "mon initial members" = "jade,emy,ruby";
      "mon host" = "192.168.111.63,192.168.111.65,192.168.111.66";
      "public network" = "192.168.111.0/24";
      "cluster network" = "192.168.111.0/24";
    };
    
    mon = {
      enable = true;
      daemons = [ "jade" ];
    };
  };
}

