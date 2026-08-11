{ pkgs, ... }:
{
  xsession.enable = true;
  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = "Mod4";
      terminal = "kitty";
      menu = "${pkgs.rofi}/bin/rofi -show drun";

      colors = {
        focused = { border = "#9d4edd"; background = "#1a1a2e"; text = "#ffffff"; indicator = "#9d4edd"; childBorder = "#9d4edd"; };
        unfocused = { border = "#3d3d6b"; background = "#1a1a2e"; text = "#888888"; indicator = "#3d3d6b"; childBorder = "#3d3d6b"; };
      };

      bars = [{
        position = "top";
        statusCommand = "${pkgs.i3status}/bin/i3status";
        colors = {
          background = "#1a1a2e";
          statusline = "#e0e0f0";
          focusedWorkspace = { border = "#9d4edd"; background = "#9d4edd"; text = "#1a1a2e"; };
          activeWorkspace = { border = "#3d3d6b"; background = "#3d3d6b"; text = "#e0e0f0"; };
          inactiveWorkspace = { border = "#1a1a2e"; background = "#1a1a2e"; text = "#888888"; };
        };
      }];

      modes.resize = {
        "Left" = "resize shrink width 10px";
        "Down" = "resize grow height 10px";
        "Up" = "resize shrink height 10px";
        "Right" = "resize grow width 10px";
        "Return" = "mode default";
        "Escape" = "mode default";
      };

      keybindings = pkgs.lib.mkOptionDefault {
        "Mod4+Escape" = "exec ${pkgs.i3lock-color}/bin/i3lock-color -c 1a1a2e";
        "Mod4+Shift+Escape" = "exec xset dpms force off";
        "Mod4+r" = "mode resize";
        "Mod4+Shift+space" = "floating toggle";
        "Mod4+Shift+q" = "kill";
        "Mod4+Shift+s" = "exec ${pkgs.maim}/bin/maim -s | ${pkgs.xclip}/bin/xclip -selection clipboard -t image/png";
        "Print" = "exec mkdir -p ~/Pictures/Screenshots && ${pkgs.maim}/bin/maim ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png";
        "Mod4+n" = "exec toggle-theme";
        "XF86AudioRaiseVolume" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
        "XF86AudioLowerVolume" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "XF86AudioMute" = "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };

      startup = [
        { command = "${pkgs.feh}/bin/feh --bg-fill ${../assets/wallpaper/wallpaper.jpg}"; always = true; notification = false; }
        { command = "${pkgs.picom}/bin/picom --backend glx --vsync"; notification = false; }
      ];
    };
  };

  home.packages = with pkgs; [ rofi i3lock-color maim xclip feh picom i3status ];
}