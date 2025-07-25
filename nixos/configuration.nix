# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports =
  [ 
  ]  
  ++ lib.optionals (builtins.pathExists ./hosts/current/hardware-configuration.nix) [ ./hosts/current/hardware-configuration.nix ]
  ++ lib.optionals (builtins.pathExists ./hosts/current/default.nix) [ ./hosts/current/default.nix ];


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable networking
  networking.networkmanager.enable = false;

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Select internationalisation properties.
  i18n.defaultLocale = "fr_FR.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "fr";

  # Define a user account. Don't forget to set a password with ‘passwd’.
#  users.users.charchess = {
#    isNormalUser = true;
#    description = "charchess";
#    extraGroups = [ "networkmanager" "wheel" ];
#    packages = with pkgs; [];
#  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    joe
    byobu
    tmux
    chrony
    keepalived
    docker
    nfs-utils
    git
    ceph
    openiscsi
    python3
    sudo
    agenix
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  networking.firewall.allowedTCPPorts = [ 22 80 443 10443 6789 ];
  networking.firewall.allowedTCPPortRanges = [ { from = 6800; to = 7300; } ];  
  networking.firewall.allowedUDPPorts = [ 6789 ];

  services.openssh.enable=true;
  services.openssh.settings.PermitRootLogin="without-password";
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdMpROENhrrWxRiXt38zNZt3iU25kCDDnrNOFNL+XAv7xymLQGLL3tnLGksku1+zaQeEkMXi+36Rpl9ql0fe6RYVpa53bOTD571lp6be+tXkF5wXuL36RDq2zx5088BS9PFyyGkgocIX9PXmT7JI1Cc3udVy8Uj3gLkODRyggNK2oHRUi6B7UNrYs4y5QnfpE/FqAw2XiJgmuBnvYA1eEnah8qv2fflYdvquk4okkM+3Ed8Za5KnUzJOasF1L/fkgaqmxH4aruI0L3K7biemcl9VNEt2GDxDvh9W8YwdRq6jiVKPKlEtHfQTamu0eskI9DqKka/gd5r4FpXtxh2/m2pdifAXAMHbz6sFeQvyPeQsa/EbPfC6e6lRRqYAJXQdB5ZcJ1MOncO15wJ58LDPpf2zovVmppIjLXNi/3F+cDR8Q7EZjrPa/P3K09jW824TaPD76ByWb8Fpx0S9clwca7W0xnj/CmtNRIL+aipOJ80zqtgQUsHEmlWKB52JvcapyTKMde80x2V4PbJZXlEyRreFLnVF9stOquMTZw7AG4elRCQGWhHz1/rd6fpNhLzm0ATXC3PFvPBNFuYRO3dbkE/8oaJoK3v7AtHYW5p3sBx2mxfvkQZGKTR57pDG4wGzSYPm0VleXhWLVsIQNXQ8oPRT7PP3lEqg6KuxPTKTH3Yw== charchess@truxonline-homelab"
  ];

  systemd.services.provision-once = {
    description = "Provisionne la machine en fonction de son adresse MAC";
    serviceConfig = {
      Type               = "oneshot";
      ConditionPathExists = "!/etc/nixos/hosts/current";
    };
    path = with pkgs; [ iproute2 gawk coreutils ];

    script = ''
      MAC_ADDR=$(ip -o link | awk -F' ' '$2 !~ /lo:/ {print $17}' | sed 's/://g' | head -n1)
      MAC_SPECIFIC_DIR="/etc/nixos/hosts/$MAC_ADDR"
      DEFAULT_DIR="/etc/nixos/hosts/default"

      if [ -d "$MAC_SPECIFIC_DIR" ]; then
        ln -sfn "$MAC_SPECIFIC_DIR" /etc/nixos/hosts/current
      else
        ln -sfn "$DEFAULT_DIR" /etc/nixos/hosts/current
      fi
    '';

    wantedBy = [ "multi-user.target" ];
    after    = [ "network-online.target" ];
  };
}
