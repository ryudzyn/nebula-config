{ config, pkgs, ... }:
let
  # Plymouth-тема "hud_space" (adi1090x/plymouth-themes, pack_3, GPLv3) —
  # анімація відчинення дверей космічного корабля на завантаженні, щоб і
  # boot виглядав частиною "Nebula OS", а не дефолтним екраном. Файли
  # (122 PNG-кадри + .script + .plymouth-дескриптор) закомічені напряму в
  # assets/plymouth/hud_space/ (той самий підхід, що й wallpaper.jpg/
  # roulette.html) — увесь апстрімний репозиторій тем важить ~290 МіБ
  # (80+ тем разом), фетчити його цілим заради однієї теми через Nix
  # безглуздо; large_icons/ (альтернативний набір кадрів для іншого
  # розширення) не закомічений — hud_space.script його не використовує.
  # ImageDir/ScriptFile в апстрімному .plymouth хардкоджені на
  # /usr/share/... — підміняємо на реальний $out, як і з halley/
  # gzml-visual-tools (той самий клас "апстрім розрахований на FHS" фіксу).
  plymouth-hud-space = pkgs.runCommand "plymouth-theme-hud-space" { } ''
    mkdir -p $out/share/plymouth/themes/hud_space
    cp ${../assets/plymouth/hud_space}/* $out/share/plymouth/themes/hud_space/
    substituteInPlace $out/share/plymouth/themes/hud_space/hud_space.plymouth \
      --replace-fail "/usr/share/plymouth/themes/hud_space" "$out/share/plymouth/themes/hud_space"
  '';
in
{
  boot.plymouth = {
    enable = true;
    theme = "hud_space";
    themePackages = [ plymouth-hud-space ];
  };

  # Живий тест 2026-09-29 (TODO.md Follow-up #42): пробували примусово
  # перемкнути Arc A770 з `i915` на новіший `xe` (гіпотеза -- інший шлях
  # DMA-BUF-експорту вирішить биті кадри захоплення екрана). РЕЗУЛЬТАТ:
  # НЕ допомогло -- wlrobs (OBS) падає з тим самим сегфолтом у
  # libwayland-client (той самий офсет a0cc, живо звірено), а Discord на
  # `xe` став ГІРШЕ (стрім взагалі не вантажиться для глядачів, замість
  # спотвореної картинки на i915). Відкочено назад на дефолтний `i915`.
  # WLR_DRM_NO_MODIFIERS=1 (нижче) теж уже пробували окремо -- не
  # допомогло. Обидва варіанти виключені, шукати далі не тут.
  #
  # Наступна спроба (2026-09-29): вимкнути display C-states і Panel Self
  # Refresh на i915 -- відомий клас нестабільності дисплея саме на Arc,
  # знайдено в реальному робочому Hyprland+Intel конфізі (ChrisLAS/hyprvibe)
  # і підтверджено спільнотою як типовий воркераунд для "битих"/зависаючих
  # кадрів на цій архітектурі. Ціна -- трохи вище споживання GPU (не
  # критично на десктопі, на відміну від ноутбука).
  boot.kernelParams = [ "i915.enable_dc=0" "i915.enable_psr=0" ];

  # Hyprland — єдина десктопна сесія (bspwm видалено 2026-10-03, halley
  # лишився в pkgs/halley лише як flake-пакет, у greetd/портал не підключений).
  # Сам собою реєструє свою wayland-сесію (services.displayManager.sessionPackages)
  # і власний xdg-desktop-portal-hyprland (xdg.portal.extraPortals +
  # configPackages, для ScreenCast/Screenshot з Noctalia) — нічого з цього не
  # треба дублювати вручну нижче.
  programs.hyprland.enable = true;

  # ReGreet замість tuigreet: показує список сесій (Hyprland і Steam-івська
  # gamescope-сесія з core/games.nix) і сам пам'ятає останній вибір
  # (~/.local/state або /var/lib/regreet — на відміну від tuigreet, без
  # --remember-прапорця). enable=true сам вмикає services.greetd і прописує
  # default_session.command (cage + regreet) — окремо його більше не задаємо.
  services.displayManager.regreet.enable = true;

  # Космічна тема для ReGreet — та сама adw-gtk3-dark/Papirus-Dark/
  # Bibata-Modern-Classic і та сама nebula-шпалера, що й у crew/default.nix і
  # на робочому столі, щоб грітер виглядав продовженням десктопу, а не дефолтним
  # Adwaita-екраном. background.fit = "Cover" (а не sample-івський "Contain")
  # -- заповнює весь екран без чорних смуг, image ширший за екран (3840x2160).
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
  services.displayManager.regreet.settings = {
    background = {
      path = ../assets/wallpaper/wallpaper.jpg;
      fit = "Cover";
    };
    GTK.application_prefer_dark_theme = true;
    appearance.greeting_msg = "Nebula OS — ласкаво просимо";
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  # wlroots-івський обхідний прийом для DMA-BUF-захоплення екрана на Arc A770
  # (заміна заліза 2026-09-29, деталі в TODO.md Follow-up #42): і `wlrobs`
  # (OBS), і PipeWire-шлях Discord показують биті/спотворені кадри або
  # падають з сегфолтом у libwayland-client -- швидше за все, через інший
  # формат тайлінгу DMA-BUF-буферів на Arc порівняно з AMD RX590. Змушує
  # Hyprland (композитор, не клієнт!) виділяти прості лінійні буфери замість
  # вендор-специфічного тайлінгу -- ціна: трохи менша ефективність
  # рендерингу, натомість коректність захоплення екрана. Треба на рівні
  # системної сесійної змінної (не home.sessionVariables/hl.env у
  # hyprland.lua) -- має подіяти ще ДО того, як сам композитор
  # ініціалізує DRM-бекенд, а не пізніше, коли він уже запущений.
  environment.sessionVariables.WLR_DRM_NO_MODIFIERS = "1";

  # INTEL_DEBUG=noccs-modifier (2026-09-30) -- ЖИВО ПЕРЕВІРЕНО, НЕ ДОПОМОГЛО.
  # Точна діагностика трансляції в Vesktop (той самий Electron/Chromium
  # рушій, що й stock Discord): WebRTC-шний desktop_capture валиться з
  # "Error creating EGLImage - EGL_BAD_MATCH" на DMA-BUF модифікаторі
  # 72057594037927948 = I915_FORMAT_MOD_4_TILED_DG2_RC_CCS_CC (DG2 = Arc
  # Alchemist, підтверджено в dmesg) -- CCS-стиснений формат, який
  # Chromium-івський EGL-імпорт не вміє прочитати. Гіпотеза була: цей
  # прапорець Mesa/iris (на відміну від WLR_DRM_NO_MODIFIERS вище -- та
  # змінна wlroots, Hyprland на власному рендер-беку її просто ігнорує)
  # прибере CCS-модифікатори з вибору Mesa. Живо перевірено після sysup +
  # повний релогін (обов'язково -- Mesa/EGL контекст ініціалізується раз на
  # старті компоузитора): і в процесі Hyprland, і в процесі Vesktop змінна
  # підтверджено присутня (live-verified через /proc/PID/environ), МОДИФІКАТОР
  # ЛИШИВСЯ ТОЙ САМИЙ побайтово, помилка не зникла. Так само не допомогло
  # quirks.skip_non_kms_dmabuf_formats і кілька вікон одночасно на екрані
  # (гіпотеза "single-client passthrough" теж відпала). Модифікатор обирається
  # десь нижче рівня, який ці прапорці контролюють -- де саме, ще не з'ясовано.
  # Лишаю змінну як задокументований мертвий кінець (шкоди не помічено), не як
  # робочий фікс -- TODO.md Follow-up #42 для повної хронології.
  environment.sessionVariables.INTEL_DEBUG = "noccs-modifier";

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