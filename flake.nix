{
  description = "Godot 4 development environment for civilization";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              git
              godot_4
              godot_4-export-templates-bin
              jq
              just
              mdbook
              ripgrep
              tree
            ];

            GODOT4_EXPORT_TEMPLATES = "${pkgs.godot_4-export-templates-bin}/share/godot/export_templates";

            shellHook = ''
              export GODOT_BIN="${pkgs.godot_4}/bin/godot4"
              echo "Godot 4 dev shell"
              echo "Project: civilization"
              echo "Run editor: godot4 --editor project.godot"
              echo "Run headless check: godot4 --headless --path . --quit"
            '';
          };
        }
      );
    };
}
