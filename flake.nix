{
  description = "VibeRange workshop development and validation shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          # Keep the base shell small. The experiment runner uses uvx to create
          # an isolated, on-demand Papermill environment.
          python = pkgs.python312.withPackages (ps: with ps; [
            requests
          ]);
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              python
              uv
              go
              git
              jq
              yq-go
              shellcheck
              pandoc
            ];

            shellHook = ''
              echo "VibeRange development shell"
              echo "Python: $(python3 --version)"
              echo "Run ./scripts/workshop-preflight.sh to validate the workshop."
            '';
          };
        }
      );
    };
}
