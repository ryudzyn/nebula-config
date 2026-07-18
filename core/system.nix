{ config, pkgs, ... }:

{
  # Одразу ставимо правильний місцевий час
  time.timeZone = "Europe/Berlin";

  # Основна мова системи
  i18n.defaultLocale = "uk_UA.UTF-8";

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

  # Налаштування клавіатури для іксових/вейланд сесій
  services.xserver.xkb = {
    # Додаємо німецьку розкладку для зручного набору специфічних літер і текстів
    layout = "us,ua,de";
    variant = "";
    options = "grp:alt_shift_toggle"; # Перемикання через Alt+Shift
  };
  nixpkgs.config.allowUnfree = true;
}