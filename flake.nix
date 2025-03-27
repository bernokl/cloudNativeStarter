{
  description = "virtual environments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    nix-toolbox.url = "github:DevPalace/nix-toolbox";
    nix-toolbox.inputs.flake-parts.follows = "flake-parts";
    nix-toolbox.inputs.nix2container.follows = "";
    nix-toolbox.inputs.nixpkgs.follows = "";
  };

  outputs = inputs@{ self, flake-parts, devshell, nixpkgs, nix-toolbox }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ devshell.flakeModule ./nix/devshell.nix ];

      systems = [ "x86_64-linux" ];

    };
}
