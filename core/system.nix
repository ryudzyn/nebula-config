{ config, pkgs, ... }:

{
  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "uk_UA.UTF-8";

  # Дефолтний консольний (TTY) шрифт не містить кириличних гліфів, тож навіть
  # з uk_UA-локаллю українські символи в голій консолі (nano/less/journalctl
  # тощо на tty2) показувались би квадратиками. ter-v16n (Terminus) кириличні
  # гліфи має. console.packages за замовчуванням ПОРОЖНІЙ (не містить
  # terminus_font сам по собі, попри те, що тут раніше було написано) — без
  # явного пакета setfont не знаходить ter-v16n.psf.gz і systemd-vconsole-setup
  # падає з "Unable to find file: ter-v16n" (підтверджено живим запуском).
  console.packages = [ pkgs.terminus_font ];
  console.font = "ter-v16n";
  # Перевикористовуємо ту саму xkb-розкладку (us,ua,de + alt+shift toggle),
  # що й для X11/Wayland (services.xserver.xkb нижче), у самій консолі — щоб
  # Alt+Shift перемикав на українську й там так само.
  console.useXkbConfig = true;

  # TODO: прибрати overrideAttrs, коли nixos-unstable міститиме nixpkgs 53a0206118
  # ("v4l2loopback: Use kernel make rules", 2026-10-22). До того 0.15.4 кладе у свій
  # $out індекси depmod (modules.alias.bin …), і збірка модулів ядра падає з
  # "buildEnv error: two given paths contain a conflicting subpath".
  boot.extraModulePackages = [
    (config.boot.kernelPackages.v4l2loopback.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        rm -f $out/lib/modules/*/modules.*
      '';
    }))
  ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Virtual Camera" exclusive_caps=1
  '';

  # KillUserProcesses = false (дефолт systemd/NixOS). Раніше тут стояло true
  # (коміт ce23eec, "security hardening", без пояснення), але воно вбивало
  # все, що лишалось після закриття сесії: mosh-server (SSH стартує його і
  # одразу закривається -- сервер помирав за секунду, `mosh earth` з телефона
  # не міг під'єднатись, живо перевірено 2026-10-03) і tmux-сесії після
  # обриву SSH. Для однокористувацького десктопа користі від true майже нема.
  services.logind.settings.Login.KillUserProcesses = false;

  # Своп раніше був взагалі вимкнений (hardware.nix: swapDevices = []).
  # 2026-09-13: живий `free -h` під час стріму в Discord показав 13Gi/15Gi
  # зайнятих і 385Mi вільних без жодного запасу — коли одночасно висять
  # Android Studio + gradle/kotlin daemon'и + гра + браузер + Discord,
  # система впирається в межу й ядро зависає на reclaim, що найпомітніше
  # вилазить на курсорі миші (найлатентність-чутливіше, що постійно
  # перемальовується). zram стискає RAM-своп на льоту — куди дешевше за
  # похибку в latency, ніж диск-своп, і не зношує SSD.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "uk_UA.UTF-8";
    LC_IDENTIFICATION = "uk_UA.UTF-8";
    LC_MEASUREMENT = "uk_UA.UTF-8";
    LC_MONETARY = "uk_UA.UTF-8";
    LC_NAME = "uk_UA.UTF-8";
    LC_NUMERIC = "uk_UA.UTF-8";
    LC_PAPER = "uk_UA.UTF-8";
    LC_TELEPHONE = "uk_UA.UTF-8";
    LC_TIME = "uk_UA.UTF-8";
  };

  programs.nix-ld.enable = true;
  # Сторонній Python (uv/python-build-standalone -- WhisperX у skills/watch, graphify)
  # шукає CA-сертифікати в /etc/ssl/cert.pem; NixOS дає лише ca-certificates.crt,
  # тож без цього лінку HTTPS падає з CERTIFICATE_VERIFY_FAILED
  environment.etc."ssl/cert.pem".source = "/etc/ssl/certs/ca-certificates.crt";

  # nh (і будь-який голий `nix build`/`nix eval`) на відміну від `nixos-rebuild --flake`
  # не вмикає ці фічі самостійно — без цього `nh os switch` падає з "experimental
  # Nix feature 'nix-command' is disabled".
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Автоочищення (2026-10-24, після того як диск заповнився посеред збірки).
  # Раніше був nix.gc "--delete-older-than 30d": при кількох sysup на день це
  # давало 69 поколінь і 101 ГБ store. nh clean лишає 10 останніх поколінь +
  # усі за 3 дні (відкат завжди є) і прибирає gcroots від `nix build` у проєктах.
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 10 --keep-since 3d";
    };
  };
  nix.settings = {
    auto-optimise-store = true;
    # Якщо під час збірки вільного менше 10 ГБ -- Nix сам збирає сміття, поки не
    # стане 30 ГБ; без цього великі оновлення валились з ENOSPC.
    min-free = 10 * 1024 * 1024 * 1024;
    max-free = 30 * 1024 * 1024 * 1024;
  };
  # Журнал systemd був 3.7 ГБ
  services.journald.settings.Journal.SystemMaxUse = "500M";

  # Моніторинг здоров'я диска (2026-10-04): єдиний диск -- Samsung SSD 850
  # (~2015 рік, заповнений на 81%), а SMART ніхто не читав. smartd сам знаходить
  # диски, періодично перевіряє SMART і при проблемах (знос, realloc-сектори,
  # помилки) шле сповіщення на робочий стіл через systembus-notify (Noctalia
  # його покаже) і в wall. Застереження модуля про DoS сповіщеннями від інших
  # локальних користувачів тут неактуальне -- користувач один.
  services.smartd = {
    enable = true;
    notifications.systembus-notify.enable = true;
  };
  # Знімок SMART для щотижневого звіту (crew/claude/weekly-report.sh): smartctl
  # потребує root, а звіт -- user-сервіс, тож раз на добу root кладе JSON у
  # /var/lib/smart-snapshot/ (читається всіма, секретів там немає).
  systemd.services.smart-snapshot = {
    description = "SMART snapshot for the weekly report";
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "smart-snapshot";
      StateDirectoryMode = "0755";
    };
    # smartctl повертає ненульовий код при попередженнях (бітова маска) -- це не збій
    script = ''
      for d in /dev/sd? /dev/nvme?n1; do
        [ -e "$d" ] || continue
        ${pkgs.smartmontools}/bin/smartctl -j -a "$d" > "/var/lib/smart-snapshot/$(basename "$d").json" || true
      done
      chmod 0644 /var/lib/smart-snapshot/*.json
    '';
    startAt = "daily";
  };
  systemd.timers.smart-snapshot.timerConfig.Persistent = true;

  # Cachix для Noctalia (alpha Quickshell-стек, довго компілюється локально) —
  # без цього flake.nix'ів `noctalia` вхід (гілка cachix, без nixpkgs.follows,
  # див. коментар там) все одно збирався б із джерела.
  nix.settings.extra-substituters = [ "https://noctalia.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
  ];

  # УВАГА: та сама розкладка (us,ua,de + grp:alt_shift_toggle) продубльована ще
  # в crew/hyprland/hyprland.lua (input.kb_layout/kb_options) — Hyprland не
  # читає services.xserver.xkb. Зміна розкладки — обидві копії правити разом.
  # Тут вона лишається заради консолі (console.useXkbConfig вище).
  services.xserver.xkb = {
    # Додаємо німецьку розкладку для зручного набору специфічних літер і текстів
    layout = "us,ua,de";
    variant = "";
    options = "grp:alt_shift_toggle"; # Перемикання через Alt+Shift
  };
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (pyFinal: pyPrev: {
          patool = pyPrev.patool.overridePythonAttrs (old: {
            doCheck = false;
          });
          # 4.5.0 (nixpkgs 2026-10-20): тести на таймінг падають ("returned too early,
          # elapsed=1.09s"), у кеші немає збірки -- а через moddb від нього залежить
          # lutris (core/games.nix). Прибрати, коли пакет знову буде в cache.nixos.org.
          pyrate-limiter = pyPrev.pyrate-limiter.overridePythonAttrs (old: {
            doCheck = false;
          });
        })
      ];
    })
  ];
}
