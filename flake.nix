{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nydus = {
      url = "github:markasoftware-tc/nydus-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {self, nydus, nixpkgs}:
    let system = "x86_64-linux";
    in {
      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nydus system; };
        modules = [
          ./system.nix
        ];
      };
    };
}
