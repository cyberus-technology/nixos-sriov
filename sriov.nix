{ config, pkgs, lib, ... }:
let
  cfg = config.virtualisation.cyberus.intel-graphics-sriov;
  intel-graphics-firmware = pkgs.stdenv.mkDerivation {
    pname = "intel-graphics-firmware";
    version = "4a1f9d7";

    src = builtins.fetchGit {
      url = "https://github.com/intel/intel-linux-firmware.git";
      rev = "4a1f9d7438dcfc1bd9294476d97d1b21d0f2e966";
    };

    installPhase = "
      mkdir -p $out/lib/firmware/i915
      cp *.bin $out/lib/firmware/i915
    ";
  };

  intel-sriov-kernel = pkgs.linux_6_6.override {
      argsOverride = rec {
      src = pkgs.fetchgit {
        url = "https://github.com/intel/linux-intel-lts.git";
        rev = "lts-v6.6.15-linux-240219T085932Z";
        hash = "sha256-JJXvPK0nDeoGAIIE/gAjbHor47DYYg0Uugs0fFXqrVc=";
      };
      version = "6.6.15";
      modDirVersion = "6.6.15";
    };
  };

in
{
  options.virtualisation.cyberus.intel-graphics-sriov = {
    enable = lib.mkEnableOption "Enable Intel graphics SRIOV support";

    autoStart = lib.mkOption {
      description = "Start the SRIOV enablement service during boot";
      default = true;
      type = lib.types.bool;
    };

    deviceBDF = lib.mkOption {
      description = "The BDF of the Intel graphics device";
      default = "0000:00:02.0";
      type = lib.types.str;
    };

    firmware = lib.mkOption {
      description = "The Intel graphics firmware (GuC)";
      default = intel-graphics-firmware;
      type = lib.types.package;
    };
  };

  imports = [
    ./vfio.nix
  ];

  config = lib.mkIf cfg.enable {

    boot.kernelPatches = [
      {
        name = "SR-IOV config";
        patch = null;
        extraConfig = ''
          PCI_IOV y
        '';
      }
    ];

    hardware.firmware = lib.mkBefore [ cfg.firmware ];
    hardware.enableRedistributableFirmware = true;

    boot.kernelParams = [
      "i915.force_probe=*"
      "i915.max_vfs=7"
      "intel_iommu=on"
      "split_lock_detect=off"
    ];
    boot.kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor intel-sriov-kernel);

    virtualisation.cyberus.vfio.enable = true;

    systemd.services.enableSriov = {
      description = "SRIOV Graphics card enablement";
      wantedBy = lib.mkIf cfg.autoStart [ "graphical.target"];
      after = [ "graphical.target" ];
      path = with pkgs; [ pciutils ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "enableSriov" ''
          deviceBDF=${cfg.deviceBDF}
          IFS=" " read -ra lspciString <<< "$(lspci -s $deviceBDF -n)"
          if [ "''${lspciString[1]}"=="0300" ]; then
            IFS=":" read -ra vendorDevice <<< "''${lspciString[2]}"
            echo '0' | tee -a /sys/bus/pci/devices/$deviceBDF/sriov_drivers_autoprobe
            echo '7' | tee -a /sys/bus/pci/devices/$deviceBDF/sriov_numvfs
            echo '1' | tee -a /sys/bus/pci/devices/$deviceBDF/sriov_drivers_autoprobe
            echo "''${vendorDevice[0]} ''${vendorDevice[1]}" | tee -a /sys/bus/pci/drivers/vfio-pci/new_id
            chmod 0666 /dev/vfio/*
          else
            echo "The Device at $deviceBDF is no Graphics Card"
          fi
        '';
      };
    };
  };
}
