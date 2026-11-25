# docker-yosys

Docker environment for VHDL synthesis with GHDL, Yosys, fpgather, and GTKWave.
GHDL is used for parsing of the VHDL frontend. Yosys has only a frontend to
synthese Verilog files.

## Build and test

From this repository's root:

```sh
./scripts/build.sh
./scripts/test.sh
```

Both scripts accept an optional image name and tag as their first argument.
The test script checks the tools and runs three VUnit counter tests.
Results are written under `examples/vhdl/build/ghdl/`.
See [the example documentation](examples/vhdl/README.md) for the source manifest
and direct simulation commands.

## Use the published image

After the first GitHub release has published the image:

```sh
docker run --rm -it -v "$PWD:/workspace" -w /workspace \
  ghcr.io/vhdlivery/docker-yosys:latest bash
```

## GitHub Actions and releases

Pull requests and relevant pushes to `main` build and test the image natively
on Linux AMD64 and ARM64. The checks can also be started manually.

Publishing a GitHub release builds each architecture once on its native
runner, uploads the image by digest and tests that exact image. Only after
both architectures pass are the tested images combined under release tags
at `ghcr.io/vhdlivery/docker-yosys`. The release tag is used
as the image tag, for example `v1.0.0`. Stable releases additionally update
`latest`; prereleases only publish their release tag. Draft releases and Git
tag pushes alone do not publish images.

The workflow uses the automatic `GITHUB_TOKEN`, with no Docker Hub credentials
or personal token. Organization settings must allow package creation. Check
package visibility after the first publication if anonymous pulls are desired.
Release builds bypass the build cache, so rebuilding the same release can
resolve newer unpinned Python packages.

Release builds do not use QEMU emulation. If either architecture fails its
build or tests, release tags are not updated. Uploaded digest-only images
from a failed run may remain in GHCR without release tags.
