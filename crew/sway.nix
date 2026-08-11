{ pkgs, ... }:
{
  home.packages = with pkgs; [
    grim
    slurp
    wl-clipboard
    brightnessctl
    wlogout
  ];

  wayland.windowManager.sway = {
    enable = true;
    config = {
      modifier = "Mod4";
      terminal = "kitty";
      menu = "${pkgs.fuzzel}/bin/fuzzel";

      startup = [
        { command = "dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SWAYSOCK"; }
        { command = "sh -c 'cd ~/Applications/SwiftpointX1 && ./\"Swiftpoint X1 Control Panel\"'"; }
        { command = "wlsunset -S 07:00 -s 20:00 -t 4000 -T 6500"; }
      ];

      input = {
        "type:keyboard" = {
          xkb_layout = "us,ua,de";
          xkb_options = "grp:alt_shift_toggle";
        };
      };

      output."*".bg = "${../assets/wallpaper/wallpaper.jpg} fill";

      colors = {
        focused = {
          border = "#9d4edd";
          background = "#1a1a2e";
          text = "#ffffff";
          indicator = "#9d4edd";
          childBorder = "#9d4edd";
        };
        unfocused = {
          border = "#3d3d6b";
          background = "#1a1a2e";
          text = "#888888";
          indicator = "#3d3d6b";
          childBorder = "#3d3d6b";
        };
      };

      bars = [{ command = "${pkgs.waybar}/bin/waybar"; }];

      modes = {
        resize = {
          "Left" = "resize shrink width 10px";
          "Down" = "resize grow height 10px";
          "Up" = "resize shrink height 10px";
          "Right" = "resize grow width 10px";
          "Return" = "mode default";
          "Escape" = "mode default";
        };
      };

      keybindings = pkgs.lib.mkOptionDefault {
        # Блокування/екран — тепер саме toggle, одна клавіша на все
        "Mod4+Escape" = "exec swaylock -c 1a1a2e -f";
        "Mod4+Shift+Escape" = "exec swaymsg 'output * power toggle'";

        "Mod4+w" = "exec waypaper";
        "Mod4+Shift+t" = "exec nwg-look";
        "Mod4+n" = "exec toggle-theme";
        "Mod4+Shift+r" = "exec xdg-open file://${../assets/cprogram/roulette.html}";

        # Скріншоти
        "Print" = "exec mkdir -p ~/Pictures/Screenshots && grim ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png";
        "Mod4+Shift+s" = "exec grim -g \"$(slurp)\" - | wl-copy";

        # Гучність і яскравість
        "XF86AudioRaiseVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
        "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "XF86MonBrightnessUp" = "exec brightnessctl set 5%+";
        "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";

        # Керування вікнами
        "Mod4+r" = "mode resize";
        "Mod4+Shift+space" = "floating toggle";
        "Mod4+Shift+q" = "kill";
        "Mod4+F1" = "exec mode-work";
        "Mod4+F2" = "exec mode-study";
        "Mod4+F3" = "exec mode-play";

        # Стильний вихід замість миттєвого закриття сесії
        "Mod4+Shift+e" = "exec wlogout";
      };
    };
  };

  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      modules-left = [ "sway/workspaces" "sway/mode" ];
      modules-center = [ "clock" ];
      modules-right = [ "pulseaudio" "network" "cpu" "memory" "tray" ];

      "sway/workspaces".format = "{name}";
      clock.format = "{:%H:%M   %d.%m.%Y}";
      cpu.format = "CPU {usage}%";
      memory.format = "RAM {used:0.1f}G";
      network = {
        format-wifi = " {essid}";
        format-ethernet = " Ethernet";
        format-disconnected = "Немає мережі";
      };
      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "🔇";
        format-icons.default = [ "" "" "" ];
      };
      tray.spacing = 8;
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
      }
      window#waybar {
        background: #1a1a2e;
        color: #e0e0f0;
      }
      #workspaces button.focused {
        background: #9d4edd;
        color: #1a1a2e;
      }
      #clock, #network, #pulseaudio, #cpu, #memory {
        padding: 0 10px;
        color: #c9b8ff;
      }
    '';
  };
}