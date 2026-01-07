{
  description = "Rolly - 2D sprite game with rollback netcode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # keep in sync with zig version
    zls = {
      url = "github:zigtools/zls/0.15.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.zig-overlay.follows = "zig-overlay";
    };

    zon2nix = {
      url = "github:nix-community/zon2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      zig-overlay,
      zls,
      zon2nix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ zig-overlay.overlays.default ];
        };

        # keep zig and zls in sync
        zigPkg = pkgs.zigpkgs."0.15.2";
        zlsPkg = zls.packages.${system}.default;

        raylibDeps = with pkgs; [
          xorg.libX11
          xorg.libXcursor
          xorg.libXrandr
          xorg.libXinerama
          xorg.libXi
          libGL
        ];
      in
      {
        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = pkgs.mkShell {
          buildInputs =
            [
              zigPkg
              zlsPkg
              zon2nix.packages.${system}.default
              pkgs.just
              pkgs.gdb
            ]
            ++ raylibDeps;

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath raylibDeps;
        };
      }
    );
}
