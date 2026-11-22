{
  description = "llama.cpp release package tracking ggml-org/llama.cpp";

  inputs = {
    flake-lib.url = "github:jgus-org/flake-lib/v1";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      flake-lib,
      nixpkgs,
    }:
    with builtins;
    let
      pin = import ./pin.nix;
      source = {
        owner = "ggml-org";
        repo = "llama.cpp";
        type = "github";
      };
    in
    {
      overlays.default = final: prev: {
        llama-cpp = prev.llama-cpp.overrideAttrs (
          _: previousAttrs: {
            inherit (pin) npmDepsHash version;
            # The channel's recipe bakes the build number and commit from its own release into the binary.
            cmakeFlags = previousAttrs.cmakeFlags ++ [
              (final.lib.cmakeFeature "LLAMA_BUILD_NUMBER" pin.buildNumber)
              (final.lib.cmakeFeature "LLAMA_BUILD_COMMIT" (substring 0 7 pin.sourceRev))
            ];
            # A failing test aborts every closure that depends on the package. Upstream and nixpkgs already run the suite for this upstream release.
            doCheck = false;
            preConfigure = ''
              pushd ${previousAttrs.npmRoot}
              LLAMA_BUILD_NUMBER=${pin.buildNumber} npm run build
              popd
            '';
            src = final.fetchFromGitHub {
              hash = pin.sourceHash;
              owner = source.owner;
              repo = source.repo;
              rev = pin.sourceRev;
            };
          }
        );
      };
    }
    // flake-lib.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
        orgFormatting = flake-lib.lib.mkFormatting {
          inherit self system;
        };
      in
      {
        checks =
          let
            checkPkgs = import nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
                cudaSupport = true;
              };
              overlays = [ self.overlays.default ];
            };
          in
          {
            inherit (checkPkgs) llama-cpp;
            formatting = orgFormatting.check;
          };
        formatter = orgFormatting.formatter;
        packages = {
          update-branches = flake-lib.lib.mkUpdateBranches {
            inherit pkgs source;
            pinSchema = "github-npm";
          };
          update-version = flake-lib.lib.mkUpdateVersion {
            inherit pkgs source;
            artifactHook = pkgs.lib.getExe (
              pkgs.writeShellApplication {
                name = "llama-cpp-release-artifacts";
                runtimeInputs = [
                  pkgs.gh
                  pkgs.gnused
                  pkgs.prefetch-npm-deps
                ];
                text = ''
                  WORK_DIR="$(mktemp -d)"
                  trap 'rm -rf "''${WORK_DIR}"' EXIT

                  gh api "/repos/''${GH_OWNER}/''${GH_REPO}/contents/tools/ui/package-lock.json?ref=''${NEW_REV}" \
                    -H "Accept: application/vnd.github.raw" > "''${WORK_DIR}/package-lock.json"
                  NPM_DEPS_HASH="$(prefetch-npm-deps "''${WORK_DIR}/package-lock.json")"
                  BUILD_NUMBER="$(gh api --method HEAD --include "/repos/''${GH_OWNER}/''${GH_REPO}/commits?sha=''${NEW_REV}&per_page=1" \
                    | sed -nE 's/^Link:.*[?&]page=([0-9]+)>; rel="last".*/\1/p')"

                  printf 'npmDepsHash=%s\nbuildNumber=%s\n' "''${NPM_DEPS_HASH}" "''${BUILD_NUMBER}"
                '';
              }
            );
            extraHashes = [
              "npmDepsHash"
              "buildNumber"
            ];
          };
        };
      }
    );
}
