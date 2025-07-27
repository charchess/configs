{
  imports = [
    ../../modules/ceph-keyring.nix   # <-- ici
  ];

  services.ceph-keyring = {
    enable  = true;
    fsid    = "4b687c5c-5a20-4a77-8774-487989fd0bc7";
    monName = "emy";
    monIp   = "192.168.111.63";
  };
}




