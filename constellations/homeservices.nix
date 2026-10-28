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

  # Вебка перед принтером (Sandberg USB Webcam Pro) для OctoPrint: MJPEG-стрім
  # на :8080 (/stream, /snapshot), той самий закритий файрвол -- localhost і
  # tailnet. autoStart = false -- socket activation: камера зайнята лише поки
  # хтось дивиться, через 5 хв без глядачів ustreamer виходить і вебка знову
  # вільна для Discord/OBS. HW -- готові MJPEG-кадри з камери, без
  # перекодування на CPU; якість JPEG камера регулювати не дає, тож якість =
  # роздільність (1080p). URL стріму в OctoPrint задається в UI (Settings ->
  # Webcam), а не тут: браузер телефона ходить на tailnet-IP earth, а
  # ідентифікаторів у публічному репо не тримаємо.
  services.ustreamer = {
    enable = true;
    autoStart = false;
    device = "/dev/v4l/by-id/usb-VNV_Sandberg_USB_Webcam_Pro-video-index0";
    extraArgs = [
      "--format=MJPEG"
      "--encoder=HW"
      "--resolution=1920x1080"
      "--desired-fps=15"
      # на 1080p з довгою ручною експозицією перший кадр іде >1 с (дефолтний
      # тайм-аут) -- без цього ustreamer перезапускає захоплення по колу
      "--device-timeout=5"
    ];
  };
  # Автоекспозиція камери в темряві ставить ~8 мс -- кадр чорний. Ручна
  # експозиція ~60 мс + гамма/яскравість (живо підібрано 2026-10-28); v4l2-ctl
  # налаштування скидаються при перепід'єднанні, тому -- перед кожним стартом.
  # auto_exposure окремим викликом: exposure_time приймається лише в Manual Mode.
  systemd.services.ustreamer.serviceConfig.ExecStartPre =
    let
      v4l2 = "${pkgs.v4l-utils}/bin/v4l2-ctl -d ${config.services.ustreamer.device}";
    in
    [
      "${v4l2} -c auto_exposure=1"
      "${v4l2} -c exposure_time_absolute=600,gamma=220,brightness=16"
    ];

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