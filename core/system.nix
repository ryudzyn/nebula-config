{ config, pkgs, ... }:

{
  # Одразу ставимо правильний місцевий час
  time.timeZone = "Europe/Berlin";

  # Основна мова системи
  i18n.defaultLocale = "uk_UA.UTF-8";

  # Дефолтний консольний (TTY) шрифт не містить кириличних гліфів, тож навіть
  # з uk_UA-локаллю українські символи в голій консолі (nano/less/journalctl
  # тощо на tty2) показувались би квадратиками. ter-v16n (Terminus) кириличні
  # гліфи має; console.packages вже дефолтно містить terminus_font.
  console.font = "ter-v16n";
  # Перевикористовуємо ту саму xkb-розкладку (us,ua,de + alt+shift toggle),
  # що й для X11/Wayland (services.xserver.xkb нижче), у самій консолі — щоб
  # Alt+Shift перемикав на українську й там так само.
  console.useXkbConfig = true;

  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Virtual Camera" exclusive_caps=1
  '';
  
  services.logind.settings.Login.KillUserProcesses = true;

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

  # nh (і будь-який голий `nix build`/`nix eval`) на відміну від `nixos-rebuild --flake`
  # не вмикає ці фічі самостійно — без цього `nh os switch` падає з "experimental
  # Nix feature 'nix-command' is disabled".
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Налаштування клавіатури для іксових/вейланд сесій
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
        })
      ];
    })
  ];
}