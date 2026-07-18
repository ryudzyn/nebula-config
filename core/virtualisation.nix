{ config, pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      ovmf.enable = true;   # UEFI, знадобиться для Windows 11
      swtpm.enable = true;  # емуляція TPM 2.0 — теж вимога Win11
    };
  };
  programs.virt-manager.enable = true;

  users.users.ryudzyn.extraGroups = [ "libvirtd" ];
}