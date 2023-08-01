# Features

This project **Features** is a set of reusable 'features'. Quickly add a tool/cli to a development container.

*Features* are self-contained units of installation code and development container configuration. Features are designed to install atop a wide-range of base container images (this repo focuses on **debian based images**).

> This repo follows the [**proposed**  dev container feature distribution specification](https://containers.dev/implementors/features-distribution/).

**List of features:**

* [nFPM](src/nfpm/README.md): nFPM is Not FPM - a simple deb, rpm, apk and arch linux packager written in Go.

## Usage

To reference a feature from this repository, add the desired features to a devcontainer.json. Each feature has a README.md that shows how to reference the feature and which options are available for that feature.

The example below installs the *nfpm* declared in the `./src` directory of this repository.

See the relevant feature's README for supported options.

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/lafriks/features/nfpm": {}
    }
}
```
