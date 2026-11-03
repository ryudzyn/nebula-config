{ pkgs, ... }:
let
  # Фон екрана блокування -- планета поточного столу: той самий кадр, що на робочому столі,
  # заздалегідь відрендерений assets/planets/render-lock.py (hyprlock не виконує шейдери).
  planets = [
    "mercury"
    "venus"
    "earth"
    "mars"
    "jupiter"
    "saturn"
    "uranus"
    "neptune"
  ];
  nebula-lock = pkgs.writeShellScriptBin "nebula-lock" ''
    names=(${builtins.concatStringsSep " " planets})
    page=$(hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq -r .id)
    [ "$page" -ge 1 ] 2>/dev/null || page=1
    mkdir -p "$HOME/.cache/nebula-lock"
    ln -sfn "${../assets/planets/lock}/''${names[$(( (page - 1) % 8 ))]}.jpg" "$HOME/.cache/nebula-lock/current.jpg"
    exec hyprlock
  '';
in
{
  home.packages = [ nebula-lock ];

  # Екран блокування для ETEA (Settings -> Lock screen -> hyprlock): її власний не
  # сподобався. PAM-служба -- окремо, у
  # core/desktop.nix (programs.hyprlock.enable), без неї hyprlock не прийме пароль.
  # Кольори -- зі світу Nyx (~/.config/etea/settings.json, customPlanets).

  # Блокування за простоєм і перед сном. Стартує з hyprland.lua: graphical-session.target
  # під Hyprland сам не активується. У повноекранних вікнах таймер стоїть (idle-inhibit там же).
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || nebula-lock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
      };
      listener = [
        {
          timeout = 600;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 900;
          on-timeout = "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
        }
      ];
    };
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };

      background = [
        {
          monitor = "";
          path = "/home/ryudzyn/.cache/nebula-lock/current.jpg";
          color = "rgb(06080c)";
          blur_passes = 0;
        }
      ];

      label = [
        {
          monitor = "";
          text = "$TIME";
          font_size = 96;
          font_family = "JetBrainsMono Nerd Font";
          color = "rgb(9fb0bf)";
          position = "120, 110";
          halign = "left";
          valign = "center";
        }
        # Поточна розкладка клавіатури (порядок -- як у kb_layout)
        {
          monitor = "";
          text = "$LAYOUT[US,UA,DE]";
          font_size = 14;
          font_family = "JetBrainsMono Nerd Font";
          color = "rgb(9fb0bf)";
          position = "120, -80";
          halign = "left";
          valign = "center";
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "320, 52";
          position = "120, -30";
          halign = "left";
          valign = "center";
          outline_thickness = 1;
          rounding = 8;
          outer_color = "rgb(262f39)";
          inner_color = "rgb(10151c)";
          font_color = "rgb(9fb0bf)";
          check_color = "rgb(9fb0bf)";
          fail_color = "rgb(a0524f)";
          fade_on_empty = false;
          placeholder_text = "";
          fail_text = "$ATTEMPTS";
        }
      ];
    };
  };
}
