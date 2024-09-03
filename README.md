# NixOS modules for Intel SR-IOV graphics

## Prerequisites
- Intel Iris Xe graphics card with SR-IOV support
- NixOS 24.05 or later
- VirtualBox with KVM backend (for use in a VM)

## Description
This repository provides ready-to-use NixOS modules to enable Intel's SR-IOV graphics acceleration.

The modules deploy a custom kernel and firmware to enable SR-IOV in the graphics card. Additionally, a systemd service is configured to enable the virtual functions upon boot.

## Usage

Just add the following snippet to your NixOS configuration and run `nixos-rebuild`:

```nix
let
  sriov-modules = builtins.fetchGit {
    url = "https://github.com/cyberus-technology/nixos-sriov";
    ref = "main";
  };
in
{
  ...
  imports = [
    "${sriov-modules}/sriov.nix"
  ];
  
  virtualisation.cyberus.intel-graphics-sriov.enable = true;
  virtualisation.virtualbox.host = {
    enable = true;
    enableKvm = true;
    enableHardening = false;
    addNetworkInterface = false;
  };
  ...
}
```

For further instructions, refer to https://github.com/cyberus-technology/virtualbox-kvm/blob/dev/README.intel-sriov-graphics.md. The main difference there is the Ubuntu host system, but everything else applies as described there.

## Caveats

This feature is experimental and not guaranteed to work on all machines. Feel free to reach out for support, but we provide this as convenience tooling, not a polished product.
