{ lib, config, ... }:
let cfg = config.virtualisation.cyberus.vfio;
in {
  options.virtualisation.cyberus.vfio.enable =
    lib.mkEnableOption "VFIO PCI-passthrough support";

  config = lib.mkIf cfg.enable {

    boot.kernelPatches = [{
      name = "VFIO config";
      patch = null;
      extraStructuredConfig = with lib.kernel;
        with config.boot.kernelPackages;
        {
          VFIO = yes;
          VFIO_PCI = yes;
        } // lib.mkIf (kernelAtLeast "6.2") {
          VFIO_CONTAINER = yes;
          IOMMUFD = no;
        };
    }];

    # Using VFIO requires to lock the memory that the passthrough device wants
    # to target for DMA transfers. This memory is typically the complete guest
    # physical address space.
    # Therefore, the userspace VMM application needs a memlock limit large
    # enough to lock the guest phyiscal memory. We simply give it unlimited
    # memlock capabilities.
    security.pam.loginLimits = [{
      domain = "*";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }];

    boot.kernelModules = [ "vfio-pci" ];
  };
}
