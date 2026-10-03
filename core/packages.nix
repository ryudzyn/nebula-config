# core/packages.nix
{ config, pkgs, inputs, ... }:
let
  # Discord screen-share на Wayland давало чорний кадр (портал і аудіо
  # працюють, але жодного PipeWire відео-вузла не з'являлося) -- живо
  # підтверджено 2026-09-29. Причина: nixpkgs-івська обгортка
  # (pkgs/by-name/di/discord/linux.nix) хардкодить
  # --enable-features=WaylandWindowDecorations, але ніколи не додає
  # WebRTCPipeWireCapturer -- без нього Chromium-івський desktopCapturer
  # мовчки не йде шляхом PipeWire/portal. Chromium бере ОСТАННЄ входження
  # --enable-features (не об'єднує), тож дописування через
  # officially-supported `commandLineArgs` (а не патч файлу в сторі)
  # повністю підмінює список фіч для цього прапорця, залишаючи решту як є.
  # Живо перевірено: прапорець коректно потрапляє у зібраний wrapper.
  # Зрештою з'ясувалось, що екранна трансляція desktop-застосунку Discord
  # (Canary чи stable, не важливо) дає биту картинку в іншої сторони через
  # окремий, глибший Chromium-баг на Arc A770 (TODO.md Follow-up #42) --
  # користувач перейшов на браузерну версію Discord для дзвінків/стрімів,
  # цей прапорець лишається на випадок повернення до desktop-застосунку.
  discordPipewireFlags = "--enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer";
  discord-pipewire = pkgs.discord.override { commandLineArgs = discordPipewireFlags; };

  # vivaldi-pipewire (2026-09-30, TODO.md Follow-up #43) -- заміна google-chrome:
  # живо підтверджено, що ЦЕЙ клас захоплення екрана (звичайний Chromium,
  # НЕ Discord-івський/Vesktop-івський Electron-шел) дає чисте відео на Arc
  # A770 через discord.com у браузері -- на відміну від desktop Discord і
  # Vesktop, що падають з EGL_BAD_MATCH на тому самому DMA-BUF-модифікаторі
  # (I915_FORMAT_MOD_4_TILED_DG2_RC_CCS_CC). google-chrome сам по собі
  # користувачу не сподобався (застарілий UI) -- Vivaldi той самий Chromium-
  # рушій під сучаснішим інтерфейсом. Той самий commandLineArgs-прийом, що й
  # discord-pipewire вище (officially supported override, не патч у сторі).
  vivaldi-pipewire = pkgs.vivaldi.override { commandLineArgs = discordPipewireFlags; };

  # discord-screenaudio (2026-09-30, TODO.md Follow-up #43) -- Qt6+QtWebEngine
  # клієнт (НЕ Electron), архівований апстрім (maltejur/discord-screenaudio,
  # останній комміт 2024-05), не в nixpkgs (package request #226504 висить
  # незакритим) -- деривація з нуля. Vesktop (той самий Electron/Chromium
  # рушій, що й stock Discord) живо підтвердив ту саму помилку
  # EGL_BAD_MATCH/DMA-BUF-модифікатор I915_FORMAT_MOD_4_TILED_DG2_RC_CCS_CC,
  # тож наступний кандидат -- інший рушій під капотом. ВАЖЛИВЕ застереження:
  # відео тут усе одно йде через вбудований у QtWebEngine Chromium (той самий
  # клас WebRTC desktop_capture, що й скрізь) -- "screenaudio" в назві прямо
  # про АУДІО (власний virtmic.cpp через rohrkabel/PipeWire, підмінює
  # системний звук під виглядом мікрофона -- обхід відсутності system-audio-
  # in-screenshare на Linux, той самий клас проблеми, що ми знайшли для
  # google-chrome/Zen того ж вечора). Чи впливає на VIDEO-баг конкретно ця
  # збірка QtWebEngine-Chromium (відмінна від і Electron, і stock google-
  # chrome, обидва вже перевірені з різним результатом) -- невідомо, живий
  # тест і покаже. rohrkabel -- git submodule, не тягнеться fetchFromGitHub
  # автоматично (не справжній git checkout у /nix/store) -- фетчиться окремо
  # й підкладається в postPatch, той самий трюк, що й з build-time патчами
  # нижче в crew/hyprland/default.nix. SKIP_KDE=ON -- необов'язкові
  # KF6Notifications/XmlGui/GlobalAccel не запаковуємо заради однієї фічі,
  # notify-send прапорець (--notify-send) іде в Noctalia.
  discord-screenaudio-rohrkabel = pkgs.fetchFromGitHub {
    owner = "Soundux";
    repo = "rohrkabel";
    rev = "04bfb921c44fb0d2337df70f5660899bc8d2844f";
    sha256 = "0iaq58w49zn364irwsnrxp2qw3rnd19c6bchk6slv7w4wj4jylgi";
  };
  discord-screenaudio = pkgs.stdenv.mkDerivation {
    pname = "discord-screenaudio";
    version = "1.10.1";
    src = pkgs.fetchFromGitHub {
      owner = "maltejur";
      repo = "discord-screenaudio";
      rev = "v1.10.1";
      sha256 = "0fjmw74zrb35hyx1r23yywlab3pi0yvh89sipcij9ppxv38jfb3x";
    };

    postPatch = ''
      rm -rf submodules/rohrkabel
      cp -r ${discord-screenaudio-rohrkabel} submodules/rohrkabel
      chmod -R u+w submodules/rohrkabel
    '';

    nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config pkgs.qt6.wrapQtAppsHook ];
    buildInputs = [ pkgs.qt6.qtbase pkgs.qt6.qtwebengine pkgs.pipewire ];
    # CMAKE_POLICY_VERSION_MINIMUM -- rohrkabel submodule (не оновлювався з
    # 2023) декларує cmake_minimum_required(VERSION 3.1), а сучасний CMake у
    # nixpkgs прибрав сумісність з <3.5 повністю (живо впіймано: build падав
    # на конфігурації submodule'а).
    cmakeFlags = [ "-DSKIP_KDE=ON" "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
  };
in
{
  environment.systemPackages = with pkgs; [
    git
    neovim
    kitty
    vscodium
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default # Firefox-форк, окремий flake-вхід
    # google-chrome прибрано (2026-09-30) -- заміна vivaldi-pipewire нижче,
    # той самий Chromium-рушій (чисте відео на discord.com, TODO.md #43), але
    # сучасніший UI -- користувачу не сподобався застарілий вигляд Chrome.
    vivaldi-pipewire
    retroarch # фронтенд емуляції консолей (libretro-ядра)
    # discord-canary прибрано (2026-09-30) -- стояв поряд зі stable для
    # A/B-тесту проблем зі стрімінгом; причина відпала, коли з'ясувалось, що
    # проблема глибша за конкретну збірку (Chromium-баг на Arc A770,
    # TODO.md Follow-up #42) і користувач перейшов на браузерний Discord.
    discord-pipewire
    # Vesktop (2026-09-30) -- ЖИВО ПЕРЕВІРЕНО: той самий Electron/Chromium
    # рушій, що й stock Discord, падає з ІДЕНТИЧНОЮ EGL_BAD_MATCH/DMA-BUF-
    # модифікатор помилкою (TODO.md Follow-up #43) -- не фікс, не обхід.
    # Лишаю поряд зі stable заради venmic (системне аудіо в шерингу, коли/якщо
    # видео-баг колись таки поправлять апстрім) і кращих UI-налаштувань якості.
    vesktop
    discord-screenaudio
    nemo-with-extensions # файловий менеджер (Cinnamon Nemo) з розширеннями -- стрічка шляху, архіви тощо
    prismlauncher # лаунчер Minecraft (мультиінстанс, моди)
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

    # Перегляд медіа/архівів. nsxiv лишився з bspwm-часів (X11, під Hyprland
    # іде через XWayland); Wayland-нативний imv — crew/hyprland/default.nix.
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
    nh # обгортка над nixos-rebuild, той самий `sysup`-аліас з crew/terminal/zsh.nix
    comma # `, <pkg>` -- одноразовий запуск пакета з nixpkgs без встановлення в профіль
  ];

  hardware.steam-hardware.enable = true;

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs                     # захоплення екрана напряму, без portal/PipeWire
      obs-pipewire-audio-capture # захоплення звуку конкретних застосунків
      obs-vaapi                  # апаратний енкодинг -- тепер на Intel Arc A770 (заміна RX590, 2026-09-29)
    ];
  };

  hardware.graphics = {
  enable = true;
  enable32Bit = true;
  # Заміна заліза AMD RX590 -> Intel i5-9400 + Arc A770 (2026-09-29):
  # rocmPackages.clr.icd (AMD-only ROCm OpenCL) прибрано, замість нього --
  # Intel-специфічні драйвери. intel-media-driver -- VAAPI (iHD) для DG2/Arc
  # та новіших Gen, потрібен obs-vaapi вище й апаратному декодуванню відео
  # (mpv/mpvpaper). intel-compute-runtime -- OpenCL (NEO), той самий
  # прошарок, що ROCm ICD давав для AMD -- потрібен DaVinci Resolve для
  # GPU-прискорення. Обидва -- живий тест ще не проводили (нове залізо
  # щойно встановлене), перевірити vainfo/clinfo після switch.
  extraPackages = [ pkgs.intel-media-driver pkgs.intel-compute-runtime ];
};

programs.steam.enable = true;

}