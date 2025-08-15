# Dans votre configuration.nix
{ config, pkgs, ... }:

{
# Dans votre configuration.nix

systemd.services.setup-cilium-kernel-headers-mount = {
  description = "Bind mount the current kernel headers to a stable path for Cilium";

  wantedBy = [ "multi-user.target" ];
  after = [ "local-fs.target" ];

  path = with pkgs; [ util-linux ];

  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;

    ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/kernel-headers-for-cilium";
    
    # CHEMIN FINAL CORRIGÉ AVEC ".kernel"
    ExecStart = ''
      ${pkgs.util-linux}/bin/mount --bind \
        "${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/source" \
        "/var/lib/kernel-headers-for-cilium"
    '';

    ExecStop = "${pkgs.util-linux}/bin/umount /var/lib/kernel-headers-for-cilium";
  };
};
}