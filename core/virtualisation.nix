{ config, pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true;  # емуляція TPM 2.0 — теж вимога Win11
    };
  };
  programs.virt-manager.enable = true;

  users.users.ryudzyn.extraGroups = [ "libvirtd" ];

  virtualisation.spiceUSBRedirection.enable = true;
}