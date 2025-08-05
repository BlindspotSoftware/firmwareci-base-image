# FirmwareCI Base Image

This repository provides **modular, reproducible NixOS base images** for FirmwareCI and custom hardware testing. It is intended as a robust foundation for building your own NixOS-based CI images, offering flexible configuration of kernel, firmware, packages, and services. Each image includes essential default tooling, enabling your host machine to execute any FirmwareCI test step reliably.

**Note:** Chipsec requires an older kernel version for compatibility. To run the chipsec test step, use the provided chipsec configuration or image, which is preconfigured with the appropriate kernel.

For a comprehensive overview of available FirmwareCI commands and usage, refer to the [FirmwareCI Commands Reference](https://docs.firmware-ci.com/references/2_commands/index.html).

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

### Build a Specific Image

```sh
make base
make chipsec
```

### Clean build outputs

```sh
make clean
```

The resulting images will be symlinked as `./base` and `./chipsec`.

---

## Flake Structure

- `flake.nix` – Flake entrypoint, exposes base and chipsec images as outputs.
- `modules/base.nix` – Base system options and configuration.
- `modules/kernel.nix` – Kernel options and configuration.
- `pkgs/default-tools/default.nix` – Default fwci testing tools package.
- `Makefile` – Simple build automation for images.

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
        firmwareci.base = {
          sshAccess = {
            user = "root";
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcSD9iHnCrJXkSt7aGSnfL0tVHUm+x6/EDr/FchmBfu";
          };
        };

        firmwareci.kernel = {
          version = "6.6.7";
          sha256 = "...";
          extraKernelModules = [ "dummy" "loop" ];
        };
      };
    in {
      nixosConfigurations.my-custom-image = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          firmwareci-base-image.baseConfig
          myHardwareConfig
        ];
      };
    };
}
```

---

## Configuration Options

You can override these options in your own configuration or flake:

### **firmwareci.base options**

| Option            | Type      | Default                        | Description                                         |
|-------------------|-----------|--------------------------------|-----------------------------------------------------|
| `sshAccess`       | submodule | `{ user = ""; key = ""; }`     | Add an SSH public key for a user (see below).       |
| `enableFwupd`     | bool      | `true`                         | Enable the fwupd firmware update service.           |
| `enableAllFirmware` | bool    | `true`                         | Enable all available firmware blobs.                |
| `allowBroken`     | bool      | `true`                         | Allow installation of broken packages.              |
| `allowUnfree`     | bool      | `true`                         | Allow installation of unfree packages.              |
| `includeChipSec`  | bool      | `false`                        | Include chipsec with kernel module (<= 6.12 only).  |
| `includeDefaultTools` | bool  | `true`                         | Include the default tools package in the image.     |

#### `sshAccess` submodule

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `user` | str  | `""`    | SSH user for access (e.g. `"root"`). |
| `key`  | str  | `""`    | SSH public key to add to the user's authorized_keys. |

### **firmwareci.kernel options**

| Option                    | Type                | Default   | Description                                                                                 |
|---------------------------|---------------------|-----------|---------------------------------------------------------------------------------------------|
| `version`                 | `str`               | `"6.15.8"`| Linux kernel version to use.                                                                |
| `sha256`                  | `str`               | SRI hash  | sha256 hash for the kernel tarball (must be in SRI format, e.g. `sha256-...`).              |
| `extraKernelModules`      | `list of str`       | `[]`      | Extra kernel modules to load at boot (e.g. `["dummy"]`).                                    |

---

## SSH Access and Security

**Note:**  
The default FirmwareCI images are configured to allow SSH access to the root user:

```nix
users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcSD9iHnCrJXkSt7aGSnfL0tVHUm+x6/EDr/FchmBfu"
];
```

This configuration allows FirmwareCI to securely connect to your device via SSH using a preconfigured key at `/root/.ssh/fwci` inside the test environment. You may also customize the SSH access settings to suit your specific requirements.

Example SSH transport configuration for FirmwareCI to connect to the machine:

```yaml
transport: &transport
  proto: ssh
  options:
    host: "my.network"
    user: root
    identity_file: /root/.ssh/fwci #pre-configured SSH-key
```

**Caution:**  
Do not enable this configuration on devices connected to publicly accessible networks, as it may expose your system to unauthorized access.

---

## Structure

- `flake.nix` – Flake entrypoint, exposes base and chipsec images.
- `modules/base.nix` – Base system options and configuration.
- `modules/kernel.nix` – Kernel options and configuration.
- `pkgs/default-tools/default.nix` – Default fwci testing tools package.
- `Makefile` – Simple build automation for images.

---

## Development

We welcome contributions from everyone!  
Format and lint Nix code with:

```sh
nix fmt
nix run .#statix
```

Pre-commit hooks are available via `pre-commit-hooks.nix` and will run `nixpkgs-fmt` and `statix` on all `.nix` files before commit.

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
