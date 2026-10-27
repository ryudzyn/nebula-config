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

  # OctoPrint -- друк на 3D-принтер (Artillery Sidewinder X2, /dev/ttyACM0)
  # прямо з ПК: Orca Slicer шле G-code через вкладку «Пристрій» на
  # http://localhost:5000, з телефона -- через tailnet. Порт у файрволі НЕ
  # відкритий: tailscale0 уже в trustedInterfaces (constellations/comms.nix).
  # Групу dialout сервісу модуль дає сам (SupplementaryGroups).
  services.octoprint.enable = true;

  # ModemManager (тягнеться NetworkManager-ом) прощупує кожен ttyACM
  # AT-командами -- з принтером це рве з'єднання/друк. Плата Ruby (STM32
  # Virtual COM Port) для нього невидима.
  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", ENV{ID_MM_DEVICE_IGNORE}="1"
  '';

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
    disabledDefaultBackends = [ "escl" ];
  };
}