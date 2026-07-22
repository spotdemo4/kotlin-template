{
  description = "kotlin template";

  nixConfig = {
    extra-substituters = [
      "https://nix.trev.zip"
    ];
    extra-trusted-public-keys = [
      "trev:I39N/EsnHkvfmsbx8RUW+ia5dOzojTQNCTzKYij1chU="
    ];
  };

  inputs = {
    systems.url = "github:spotdemo4/systems";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    trevpkgs = {
      url = "github:spotdemo4/trevpkgs";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      trevpkgs,
      ...
    }:
    trevpkgs.libs.mkFlake (
      system: pkgs: {

        # nix develop [#...]
        devShells = {
          default = pkgs.mkShell {
            shellHook = pkgs.shellhook.ref;
            packages = with pkgs; [
              # kotlin
              gradle_9
              jdk25
              kotlin-language-server
              ktlint

              vscode-json-languageserver # json
              yaml-language-server # yaml
              tombi # toml
              oxfmt # format

              # nix
              nixd
              nil
              nixfmt

              # util
              treefmt
              bumper
            ];
          };

          bump = pkgs.mkShell {
            packages = with pkgs; [
              bumper
            ];
          };

          release = pkgs.mkShell {
            packages = with pkgs; [
              flake-release
            ];
          };

          update = pkgs.mkShell {
            packages = with pkgs; [
              gradle_9
              jdk25
              renovate
            ];
          };

          vulnerable = pkgs.mkShell {
            packages = with pkgs; [
              osv-scanner # kotlin
              flake-checker # nix
              zizmor # actions
            ];
          };
        };

        # nix run [#...]
        apps = pkgs.mkApps {
          dev = {
            script = "gradle run";
            packages = with pkgs; [
              gradle_9
              jdk25
            ];
          };
          test = {
            script = "gradle test";
            packages = with pkgs; [
              gradle_9
              jdk25
            ];
          };
          update-deps = {
            script = ''
              gradle installDist test --write-locks
              update_script=$(nix build .#default.mitmCache.updateScript --no-link --print-out-paths)
              USE_BWRAP=0 "$update_script"
              oxfmt --write deps.json
            '';
            packages = with pkgs; [
              gradle_9
              jdk25
              oxfmt
            ];
          };
        };

        # nix build [#...]
        packages = {
          default = pkgs.stdenv.mkDerivation (
            final: with pkgs.lib; {
              pname = "kotlin-template";
              version = "0.1.1";

              src = fileset.toSource {
                root = ./.;
                fileset = fileset.unions [
                  ./build.gradle.kts
                  ./deps.json
                  ./gradle.lockfile
                  ./gradle.properties
                  ./settings.gradle.kts
                  ./LICENSE
                  ./src
                ];
              };

              nativeBuildInputs = with pkgs; [
                gradle_9
                jdk25
                ktlint
                makeWrapper
              ];

              mitmCache = pkgs.gradle_9.fetchDeps {
                pkg = final.finalPackage;
                data = ./deps.json;
              };
              __darwinAllowLocalNetworking = true;

              gradleBuildTask = "installDist";
              gradleUpdateTask = "installDist test";
              gradleCheckTask = "test";
              doCheck = true;
              doInstallCheck = pkgs.stdenv.buildPlatform.canExecute pkgs.stdenv.hostPlatform;

              postCheck = ''
                ktlint --relative . "src/**/*.kt" "*.gradle.kts"
              '';

              installPhase = ''
                runHook preInstall

                mkdir -p "$out"
                cp -R build/install/kotlin-template/. "$out"
                wrapProgram "$out/bin/kotlin-template" \
                  --set JAVA_HOME "${pkgs.jdk25}" \
                  --prefix PATH : "${
                    makeBinPath (
                      with pkgs;
                      [
                        coreutils
                        findutils
                        gnused
                        jdk25
                      ]
                    )
                  }"

                runHook postInstall
              '';

              installCheckPhase = ''
                runHook preInstallCheck
                test "$("$out/bin/kotlin-template")" = "Hello, World!"
                runHook postInstallCheck
              '';

              meta = {
                mainProgram = "kotlin-template";
                description = "kotlin template";
                license = licenses.mit;
                platforms = pkgs.jdk25.meta.platforms;
                homepage = "https://trev.zip/template/kotlin";
                changelog = "https://trev.zip/template/kotlin/releases";
                downloadPage = "https://trev.zip/template/kotlin/releases/tag/v${final.version}";
              };
            }
          );
        };

        # nix build #images.[...]
        images = {
          default = pkgs.mkImage {
            src = self.packages.${system}.default;
          };
        };

        # nix build #appimages.[...]
        appimages = {
          default = pkgs.mkAppImage {
            src = self.packages.${system}.default;
          };
        };

        # nix fmt
        formatter = pkgs.treefmt.withConfig {
          configFile = ./treefmt.toml;
          runtimeInputs = with pkgs; [
            ktlint
            nixfmt
            oxfmt
          ];
        };

        # nix flake check
        checks = pkgs.mkChecks {
          kotlin = self.packages.${system}.default;

          nix = {
            root = ./.;
            filter = file: file.hasExt "nix";
            packages = with pkgs; [
              nixfmt
            ];
            script = ''
              nixfmt --check "$file"
            '';
          };

          actions-gh = {
            root = ./.github/workflows;
            filter = file: file.hasExt "yaml";
            packages = with pkgs; [
              action-validator
              zizmor
            ];
            script = ''
              action-validator "$file"
              zizmor --offline "$file"
            '';
          };

          actions-fj = {
            root = ./.forgejo/workflows;
            filter = file: file.hasExt "yaml";
            packages = with pkgs; [
              forgejo-runner
              zizmor
            ];
            script = ''
              forgejo-runner validate --workflow --path "$file"
              zizmor --offline "$file"
            '';
          };

          renovate-gh = {
            root = ./.github;
            files = ./.github/renovate.json;
            packages = with pkgs; [
              renovate
            ];
            script = ''
              renovate-config-validator renovate.json
            '';
          };

          renovate-fj = {
            root = ./.forgejo;
            files = ./.forgejo/renovate.json;
            packages = with pkgs; [
              renovate
            ];
            script = ''
              renovate-config-validator renovate.json
            '';
          };

          config = {
            root = ./.;
            filter = file: file.hasExt "json" || file.hasExt "yaml" || file.hasExt "toml" || file.hasExt "md";
            packages = with pkgs; [
              oxfmt
            ];
            script = ''
              oxfmt --check
            '';
          };
        };
      }
    );
}
