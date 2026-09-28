{ config, pkgs, ... }:
# Базова "справність робочого столу" -- без цього блоку девмон/файловий
# менеджер не бачили б USB-флешки (devmon/gvfs/udisks2 -- автомонтування),
# файли не мали б превʼю-іконок (tumbler), SSD не тримався б у формі
# (fstrim -- періодичний TRIM), а тачпад/сенсорика не працювали б узагалі
# (libinput).
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