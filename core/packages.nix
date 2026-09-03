# core/packages.nix
{ config, pkgs, self, inputs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    neovim
    kitty
    self.packages.${pkgs.stdenv.hostPlatform.system}.halley
    vscodium
    google-chrome
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    retroarch
    xwayland-satellite
    discord-canary
    nemo-with-extensions
    prismlauncher
    mako
    # Wayland idle-manager для halley-сесії (пара до nebula-awake в
    # crew/bspwm.nix, який робить те саме для X11/bspwm через systemd-inhibit) —
    # halley поки не має власного home-manager-модуля/autostart-конфіга в
    # цьому репо, тож stasis зараз не підключений жодним конфіг-файлом/юнітом.
    stasis
    libva-utils
    jetbrains.idea-oss
    claude-code
    
    # Творчі
    kdePackages.kdenlive
    lmms
    ardour
    easyeffects
    deepfilternet
    gimp

    # Особисте
    obsidian
    ludusavi
    proton-vpn
    anki
    goldendict-ng
    keepassxc

    # Перегляд медіа/архівів — раніше не було жодного плеєра/переглядача
    # взагалі, тільки feh для встановлення шпалер (crew/bspwm.nix). nsxiv, не
    # imv/loupe — той самий нативний X11 підхід, що й dunst замість mako
    # (crew/bspwm.nix:365), без зайвих Wayland-залежностей заради сесії,
    # якої зараз немає.
    mpv
    nsxiv
    xarchiver
    p7zip

    # Системні утиліти
    appimage-run
    lm_sensors
    gnome-disk-utility
    rclone
    unrar
    unzip
    mesa-demos
    inxi
    pavucontrol
    libnotify
    nixfmt
    pciutils
    usbutils
    v4l-utils
    ethtool
    wget
    ncdu
    lact
    nh
  ];

  hardware.steam-hardware.enable = true;

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs                     # захоплення екрана напряму, без portal/PipeWire
      obs-pipewire-audio-capture # захоплення звуку конкретних застосунків
      obs-vaapi                  # апаратний енкодинг на AMD (в тебе RX 590)
    ];
  };

  systemd.packages = [ pkgs.lact ];
  systemd.services.lactd.wantedBy = [ "multi-user.target" ];

  hardware.graphics = {
  enable = true;
  enable32Bit = true;
};

programs.steam.enable = true;

}