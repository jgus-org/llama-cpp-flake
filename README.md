# llama-cpp

A Nix flake that provides [llama.cpp](https://github.com/ggml-org/llama.cpp) at a pinned upstream release, delivered as a nixpkgs overlay.

## Outputs

- `overlays.default`: the deployment interface. It replaces `pkgs.llama-cpp` with the pinned release build in whatever package set you apply it to. It is not system-scoped.

## Notes

- The override changes the source and the build recipe only, so the backend selection and the `cudaPackages` that the built library depends on remain the ones your own package set is configured with. A GPU consumer that builds torch, or anything else native, from a _different_ package set will disagree with this llama.cpp about the CUDA major version. The disagreement shows up as a load failure against the CUDA backend's `libggml-cuda.so`. Compose the overlays on one package set.
- The build does not run upstream's test suite, which the channel's own recipe runs.
- nixpkgs' own `meta.platforms` for llama-cpp is the Unix list, which covers all three published systems. nixpkgs marks the Darwin systems unsupported in a package set that enables CUDA or OpenCL, so `llama-cpp` on Darwin resolves only in a CPU- or Metal-configured package set.
- The package's version is the release it pins. The build number and commit it reports (`llama-server --version`, `/props`, and the web UI) are that release's, not the consuming package set's.

See [LICENSE.md](LICENSE.md) for licensing and copyright, and [NOTICE.md](NOTICE.md) for the terms of upstream and distributed artifacts.
