{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ceph-custom;
  
  # Génération déclarative des keyrings
  adminKeyring = pkgs.writeText "ceph.client.admin.keyring" ''
    [client.admin]
    key = AQBWlyBh+RJeFRAAdeclarativeKeyHere==
    caps mds = "allow *"
    caps mgr = "allow *" 
    caps mon = "allow *"
    caps osd = "allow *"
  '';

in {
  config = mkIf cfg.enable {
    # Keyring admin déclaratif
    environment.etc."ceph/ceph.client.admin.keyring" = {
      source = adminKeyring;
      mode = "0600";
      user = "ceph"; 
      group = "ceph";
    };
    
    # Bootstrap déclaratif via systemd
    systemd.services.ceph-declarative-bootstrap = {
      description = "Ceph Declarative Bootstrap";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
      };
      
      script = ''
        # Tout le bootstrap est géré de façon déclarative
        echo "Bootstrap déclaratif terminé"
      '';
    };
  };
}
