# FirmwareCI Base Image

This repository provides a **modular, reproducible NixOS base image** for FirmwareCI and custom hardware testing. It is designed to be used as a foundation for your own NixOS-based CI images, with flexible options for kernel, firmware, packages, and services.

---

## Features

- **Nix Flake-based**: Modern, reproducible, and composable.
- **Easy to extend**: Use as a base for your own hardware.

---

## Quick Start

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled (`experimental-features = nix-command flakes` in your `nix.conf`).

### Build All Images

```sh
make all
```

### Build a Base Image

```sh
make base
```

### Build a Test Image (with extra packages)

```sh
make test-image
```

### Clean build outputs

```sh
make clean
```

The resulting images will be symlinked as `./base` and `./test-image`.

---

## Using as a Base for Your Own Image

You can use this flake as a base for your own NixOS image or configuration.

### Example: Extend in Your Own Flake

```nix
{
  description = "My Custom FirmwareCI Image";

  inputs.firmwareci-base-image.url = "github:BlindspotSoftware/firmwareci-base-image";

  outputs = { self, nixpkgs, firmwareci-base-image, ... }:
    let
      myHardwareConfig = { ... }: {
        # Add your own hardware modules or options here
        firmwareciBase = {
            extraPackages = [ pkgs.htop pkgs.lm_sensors ];
            enableSSH = true;
            sshPermitRootLogin = "yes";
            allowUnfree = true;
            allowBroken = false;
        };

        firmwareci.kernel = {
            version = "6.6.7";
            sha256 = "sha256-NEWVALUE";
            extraKernelModules = [ "dummy" "loop" ];
        };
      };
    in {
      nixosConfigurations.my-custom-image = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          firmwareci-base-image.nixosConfigurations.firmwareci-base.config
          myHardwareConfig
        ];
      };
    };
}
```

---

## Configuration Options

You can override these options in your own configuration or flake:

### **firmwareciBase options**

| Option                    | Type                | Default   | Description                                                                                 |
|---------------------------|---------------------|-----------|---------------------------------------------------------------------------------------------|
| `extraPackages`           | `list of package`   | `[]`      | Extra packages to install in the image.                                                     |
| `enableSSH`               | `bool`              | `false`   | Enable the OpenSSH service.                                                                 |
| `sshPermitRootLogin`      | `str`               | `"no"`    | Value for `PermitRootLogin` in SSH config (`"yes"`, `"no"`, `"prohibit-password"`, etc.).   |
| `enableFwupd`             | `bool`              | `true`    | Enable the [fwupd](https://fwupd.org/) firmware update service.                             |
| `enableAllFirmware`       | `bool`              | `true`    | Enable all available firmware blobs for maximum hardware compatibility.                     |
| `allowUnfree`             | `bool`              | `false`   | Allow installation of unfree (proprietary) packages.                                        |
| `allowBroken`             | `bool`              | `false`   | Allow installation of packages marked as broken in Nixpkgs.                                 |

### **firmwareci.kernel options**

| Option                    | Type                | Default   | Description                                                                                 |
|---------------------------|---------------------|-----------|---------------------------------------------------------------------------------------------|
| `version`                 | `str`               | `"6.15.8"`| Linux kernel version to use.                                                                |
| `sha256`                  | `str`               | SRI hash  | sha256 hash for the kernel tarball (must be in SRI format, e.g. `sha256-...`).              |
| `extraKernelModules`      | `list of str`       | `[]`      | Extra kernel modules to load at boot (e.g. `["dummy"]`).                           |

---

## Structure

- `flake.nix` – Flake entrypoint, exposes base and test images.
- `modules/kernel.nix` – Kernel options and configuration.
- `modules/firmwareci.nix` – Base system options and configuration.
- `pkgs/default-tools/default.nix` – Default fwci testing tools package.
- `Makefile` – Simple build automation for images.

---

## Development

- Format and lint Nix code with:
  ```sh
  nix fmt
  nix run .#statix
  ```
- Pre-commit hooks are available via `pre-commit-hooks.nix` and will run `nixpkgs-fmt` and `statix` on all `.nix` files before commit.

---

## License

[BSD 2-Clause License](LICENSE)

---

## Maintainers

- [@BlindspotSoftware](https://github.com/orgs/BlindspotSoftware)

---

## Contributing

Contributions and issues are welcome! Please open a PR or issue on GitHub.

---

## References

- [NixOS](https://nixos.org/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)