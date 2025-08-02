{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  
  outputs = { self, nixpkgs }: {
    nixosConfigurations.jade = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./nixos/hosts/jade/configuration.nix ];
    };
  };
}
