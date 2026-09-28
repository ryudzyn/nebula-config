# core/packages.nix
{ config, pkgs, self, inputs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    neovim
    kitty
    self.packages.${pkgs.stdenv.hostPlatform.system}.halley # власний Wayland-компоузитор (pkgs/halley), дефолтна greetd-сесія
    vscodium
    google-chrome
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default # Firefox-форк, окремий flake-вхід
    retroarch # фронтенд емуляції консолей (libretro-ядра)
    xwayland-satellite # Xwayland-сумісність для halley (сам не тягне вбудований Xwayland)
    discord-canary
    # Звичайний (stable) Discord поряд з Canary — для A/B-тесту підвисання
    # курсора під час стріму (2026-09-13, TODO.md?): Canary — нічна збірка,
    # історично більше багів навколо Linux screen-share, ніж у stable.
    discord
    nemo-with-extensions # файловий менеджер (Cinnamon Nemo) з розширеннями -- стрічка шляху, архіви тощо
    prismlauncher # лаунчер Minecraft (мультиінстанс, моди)
    mako # нотифікації для halley-сесії (dunst -- X11/bspwm-еквівалент, crew/bspwm.nix)
    # Wayland idle-manager для halley-сесії (пара до nebula-awake в
    # crew/bspwm.nix, який робить те саме для X11/bspwm через systemd-inhibit) —
    # halley поки не має власного home-manager-модуля/autostart-конфіга в
    # цьому репо, тож stasis зараз не підключений жодним конфіг-файлом/юнітом.
    stasis
    libva-utils # діагностика VAAPI (vainfo) -- апаратне відео-прискорення
    # idea-oss дискантинуйований і позначений insecure в nixpkgs (JetBrains
    # злили Community в єдиний дистрибутив 2025) — jetbrains.idea:
    # безкоштовні фічі працюють без ліцензії, платні розблоковуються нею.
    jetbrains.idea
    claude-code

    # Android-розробка (проєкт orbit) — Android Studio дає AVD Manager +
    # апаратно прискорений емулятор (KVM вже є через core/virtualisation.nix)
    # для тестування apk без встановлення на реальний телефон; android-tools
    # (adb/fastboot) — системно, а не через nix-shell щоразу
    android-studio
    android-tools
    
    # Творчі
    kdePackages.kdenlive
    lmms
    ardour
    easyeffects
    deepfilternet
    gimp
    qpwgraph # візуальний патчбей для PipeWire-графа з'єднань, pavucontrol сам цього не вміє

    # Особисте
    obsidian
    ludusavi # бекап/синхронізація ігрових сейвів (крос-платформна база ігор)
    proton-vpn
    anki
    goldendict-ng
    keepassxc

    # Перегляд медіа/архівів — раніше не було жодного плеєра/переглядача
    # взагалі. nsxiv, не imv/loupe — той самий нативний X11 підхід, що й
    # dunst замість mako (crew/bspwm.nix:365), без зайвих Wayland-залежностей
    # заради сесії, якої зараз немає (imv для Hyprland — crew/hyprland/default.nix).
    mpv
    syncplay # синхронний перегляд відео з кимось віддалено (той самий mpv-бекенд)
    nsxiv
    xarchiver
    p7zip
    zathura # PDF -- досі не було жодного переглядача
    ani-cli
    davinci-resolve
    clinfo # діагностика ROCm OpenCL — `clinfo` після switch покаже, чи бачить GPU

    # Системні утиліти
    appimage-run
    lm_sensors
    gnome-disk-utility
    rclone # синхронізація з хмарними сховищами, купа providers
    unrar
    unzip
    mesa-demos # glxgears/glxinfo -- швидка ручна перевірка GL/GPU
    inxi # детальний системний звіт (CPU/GPU/диски/мережа) одним викликом
    pavucontrol
    libnotify
    nixfmt
    pciutils
    usbutils
    v4l-utils
    ethtool
    wget
    ncdu
    lact # GUI+daemon керування AMD GPU (фан-крива, ліміти потужності) -- AMD-only, RX 590
    nh # обгортка над nixos-rebuild, той самий `sysup`-аліас з crew/terminal/zsh.nix
    comma # `, <pkg>` -- одноразовий запуск пакета з nixpkgs без встановлення в профіль
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
  # ROCm OpenCL ICD — потрібен DaVinci Resolve для GPU-прискорення на AMD.
  # RX 590 (Polaris10/gfx803) офіційно поза підтримкою свіжого ROCm — тож не
  # гарантія, що rocminfo побачить картку, перевіряти тільки живим тестом.
  extraPackages = [ pkgs.rocmPackages.clr.icd ];
};

programs.steam.enable = true;

}