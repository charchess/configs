{ lib, ... }:

{
  cephCluster = {
    nodes = {
      jade = {
        hostname = "jade";
        address = "192.168.111.63";  # Vérifiez que c'est bien la bonne IP
        roles = [ "mon" "mgr" ];
        osds = [ "/dev/sdb" ];
      };
      
      emy = {
        hostname = "emy"; 
        address = "192.168.111.65";
        roles = [ "mon" "osd" ];
        osds = [ "/dev/sda" ];
      };
      
      ruby = {
        hostname = "ruby";
        address = "192.168.111.66"; 
        roles = [ "mon" "osd" ];
        osds = [ "/dev/sdc" ];
      };
    };
  };
}
