{ config, pkgs, ... }:
{
  services.libinput.enable = true;
  services.fstrim.enable = true;
  services.devmon.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.tumbler.enable = true;

  services.printing = {
    enable = true;
    drivers = [ pkgs.brlaser ];
  };

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
    disabledDefaultBackends = [ "escl" ];
  };
}