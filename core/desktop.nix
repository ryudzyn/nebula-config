{
  config,
  pkgs,
  ...
}:
let
  # Plymouth-тема "nebula" (2026-11-12, замінила hud_space з adi1090x) у стилі решти
  # Nebula OS: Земля з тими самими текстурами й світлом, що планети ETEA і hyprlock,
  # Місяць на нахиленій орбіті, а
  # прогрес завантаження -- точки орбіти, що засвічуються. Картинки -- з
  # assets/plymouth/nebula/render.py (закомічені, як і lock/*.jpg). Шрифт для
  # динамічного рядка (пароль, повідомлення) -- boot.plymouth.font нижче.
  plymouth-nebula = pkgs.runCommand "plymouth-theme-nebula" { } ''
    dir=$out/share/plymouth/themes/nebula
    mkdir -p $dir
    cp ${../assets/plymouth/nebula}/*.png ${../assets/plymouth/nebula}/nebula.script $dir/
    substitute ${../assets/plymouth/nebula}/nebula.plymouth $dir/nebula.plymouth --subst-var-by out $dir
  '';
in
{
  boot.plymouth = {
    enable = true;
    theme = "nebula";
    themePackages = [ plymouth-nebula ];
    font = "${pkgs.jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Light.ttf";
  };

  # Живий тест 2026-09-29 (TODO.md Follow-up #42): пробували примусово
  # перемкнути Arc A770 з `i915` на новіший `xe` (гіпотеза -- інший шлях
  # DMA-BUF-експорту вирішить биті кадри захоплення екрана). РЕЗУЛЬТАТ:
  # НЕ допомогло -- wlrobs (OBS) падає з тим самим сегфолтом у
  # libwayland-client (той самий офсет a0cc, живо звірено), а Discord на
  # `xe` став ГІРШЕ (стрім взагалі не вантажиться для глядачів, замість
  # спотвореної картинки на i915). Відкочено назад на дефолтний `i915`.
  # WLR_DRM_NO_MODIFIERS=1 теж пробували окремо -- не допомогло. Обидва
  # варіанти виключені, шукати далі не тут.
  #
  # Наступна спроба (2026-09-29): вимкнути display C-states і Panel Self
  # Refresh на i915 -- відомий клас нестабільності дисплея саме на Arc,
  # знайдено в реальному робочому Hyprland+Intel конфізі (ChrisLAS/hyprvibe)
  # і підтверджено спільнотою як типовий воркераунд для "битих"/зависаючих
  # кадрів на цій архітектурі. Ціна -- трохи вище споживання GPU (не
  # критично на десктопі, на відміну від ноутбука).
  boot.kernelParams = [
    "i915.enable_dc=0"
    "i915.enable_psr=0"
  ];

  # Hyprland — єдина десктопна сесія (bspwm видалено 2026-10-03, halley
  # лишився в pkgs/halley лише як flake-пакет, у greetd/портал не підключений).
  # Сам собою реєструє свою wayland-сесію (services.displayManager.sessionPackages)
  # і власний xdg-desktop-portal-hyprland (xdg.portal.extraPortals +
  # configPackages, для ScreenCast/Screenshot з Noctalia) — нічого з цього не
  # треба дублювати вручну нижче.
  # (Тут був overlay з окремим nixpkgs-hyprland заради Hyprland 0.57.1 -- у 0.56.2
  # захоплення вікна без монітора валило композитор. Прибрано 2026-11-11: основний
  # nixpkgs наздогнав 0.57.1.)

  programs.hyprland.enable = true;
  # PAM-служба для hyprlock; вигляд -- у crew/hyprlock.nix
  programs.hyprlock.enable = true;

  # ReGreet замість tuigreet: показує список сесій (Hyprland і Steam-івська
  # gamescope-сесія з core/games.nix) і сам пам'ятає останній вибір
  # (~/.local/state або /var/lib/regreet — на відміну від tuigreet, без
  # --remember-прапорця). enable=true сам вмикає services.greetd і прописує
  # default_session.command (cage + regreet) — окремо його більше не задаємо.
  services.displayManager.regreet.enable = true;

  # Космічна тема для ReGreet — та сама adw-gtk3-dark/Papirus-Dark/
  # Bibata-Modern-Classic і та сама nebula-шпалера, що й у crew/default.nix і
  # на робочому столі, щоб грітер виглядав продовженням десктопу, а не дефолтним
  # Adwaita-екраном. background-size: cover (а не contain) -- заповнює весь
  # екран без чорних смуг, image ширший за екран (3840x2160).
  services.displayManager.regreet.theme = {
    name = "adw-gtk3-dark";
    package = pkgs.adw-gtk3;
  };
  services.displayManager.regreet.iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme;
  };
  services.displayManager.regreet.cursorTheme = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
  };
  # Шпалера — через CSS, а НЕ через settings.background.path (TODO.md
  # Follow-up #45, причина зависання грітера). ReGreet 0.5 вантажить
  # background.path через glycin, а пакет у nixpkgs зібраний без
  # glycin-loaders/bubblewrap — завантаження тихо падає, і ReGreet
  # відкатується на gtk::MediaFile: GStreamer безкінечно «програє» JPG як
  # відео в циклі (потік gstglcontext жере ~75% CPU), поки GUI не зависне
  # намертво. GTK-івський CSS декодує JPEG сам, без glycin і GStreamer.
  services.displayManager.regreet.settings = {
    GTK.application_prefer_dark_theme = true;
    appearance.greeting_msg = "Nebula OS — ласкаво просимо";
  };
  services.displayManager.regreet.extraCss = ''
    window {
      background-image: url("file://${../assets/wallpaper/wallpaper.jpg}");
      background-size: cover;
      background-position: center;
    }
  '';

  # Автовхід лише при старті greetd (тобто після завантаження): одразу Hyprland
  # без пароля, а hyprland.lua бачить NEBULA_AUTOLOGIN і першим ділом вмикає
  # hyprlock. Навіщо: після перезавантаження з телефона робочий стіл (ETEA,
  # Sunshine тощо) піднімається сам, а за ПК все одно потрібен пароль. Після
  # виходу з сесії -- звичайний ReGreet. Діє з наступного старту greetd (switch
  # його не перезапускає).
  services.greetd.settings.initial_session = {
    user = "ryudzyn";
    command = "env NEBULA_AUTOLOGIN=1 ${config.programs.hyprland.package}/bin/start-hyprland";
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  # WLR_DRM_NO_MODIFIERS=1 і INTEL_DEBUG=noccs-modifier тут раніше стояли як
  # спроби вилікувати биту демонстрацію екрана на Arc A770 -- обидві живо
  # перевірені й не діяли, прибрано 2026-10-04. WLR_DRM_NO_MODIFIERS --
  # змінна wlroots, Hyprland її не читає; INTEL_DEBUG не впливає на список
  # модифікаторів, який XDPH бере з linux-dmabuf таблиці Hyprland. Не
  # повертати -- повна хронологія в TODO.md #42, #43, #49.

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    # Без config.common-оверрайду ScreenCast/Screenshot: раніше він форсив
    # halley-портал для ВСІХ сесій і ламав скріншоти Noctalia та screen-share
    # під Hyprland (TODO.md Follow-up #41). Кожна сесія сама бере свій портал
    # за UseIn= у .portal-файлі.
    config.common.default = [ "gtk" ];
  };
}
