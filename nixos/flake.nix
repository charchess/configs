# /etc/nixos/flake.nix
{
  description = "Ma configuration NixOS pour toutes mes machines";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }: {
    # On définit ici toutes les configurations possibles de nos machines
    nixosConfigurations = {

      # Définition pour la machine "jade"
      jade = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { }; # Peut contenir des arguments spéciaux
        modules = [
          ./configuration.nix
#          ./hosts/jade/default.nix
          ./hosts/jade/network.nix
        ];
      };

      # Définition pour la machine "grenat"
      grenat = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
#          ./hosts/grenat/default.nix
          ./hosts/grenat/network.nix
        ];
      };

     # Définition pour la machine "emy"
      emy = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
#          ./hosts/emy/default.nix
          ./hosts/emy/network.nix
        ];
      };

     # Définition pour la machine "ruby"
      ruby = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
#          ./hosts/ruby/default.nix
          ./hosts/ruby/network.nix
        ];
      };

     # Définition pour la machine "VM-nix"
      VM-nix = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          ./hosts/VM-nix/default.nix
          ./hosts/VM-nix/network.nix
        ];
      };
    };
  };
}