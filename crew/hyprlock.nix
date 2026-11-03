{ ... }:
{
  # Екран блокування для ETEA (Settings -> Lock screen -> hyprlock): її власний не
  # сподобався, а Noctalia блокує лише поки сама запущена. PAM-служба -- окремо, у
  # core/desktop.nix (programs.hyprlock.enable), без неї hyprlock не прийме пароль.
  # Кольори -- зі світу Nyx (~/.config/etea/settings.json, customPlanets).
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
          path = "screenshot";
          color = "rgb(06080c)";
          blur_passes = 3;
          blur_size = 8;
          brightness = 0.35;
        }
      ];

      label = [
        {
          monitor = "";
          text = "$TIME";
          font_size = 120;
          font_family = "JetBrainsMono Nerd Font";
          color = "rgb(9fb0bf)";
          position = "0, 160";
          halign = "center";
          valign = "center";
        }
        # Поточна розкладка клавіатури (порядок -- як у kb_layout)
        {
          monitor = "";
          text = "$LAYOUT[US,UA,DE]";
          font_size = 14;
          font_family = "JetBrainsMono Nerd Font";
          color = "rgb(9fb0bf)";
          position = "0, -110";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "320, 52";
          position = "0, -60";
          halign = "center";
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
