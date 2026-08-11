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
    wget
    ncdu
    lact
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