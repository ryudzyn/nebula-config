{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    lutris
    heroic
    bottles
    ryubing
    wineWow64Packages.staging
    gamescope
  ];

  services.xserver.enable = true;
  services.xserver.windowManager.i3.enable = true;
  services.xserver.windowManager.bspwm.enable = true;
  services.xserver.xkb = {
    layout = "us,ua,de";
    options = "grp:alt_shift_toggle";
  };

  programs = {
    gamemode.enable = true;
    steam = {
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      gamescopeSession = {
        enable = true;
        args = [ "--rt" "--expose-wayland" ];
      };
    };
    gamescope = {
      enable = true;
      capSysNice = true;
      args = [ "--rt" "--expose-wayland" ];
    };
  };

    programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true; # щоб GTK-застосунки (типу файлових діалогів) виглядали й працювали нормально
  };

    xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
    config.sway = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
    };
  };

  home-manager.sharedModules = [
    (_: {
      programs.mangohud = {
        enable = true;
        enableSessionWide = true;
        settings = {
          no_display = true;
          fps_limit = [ 60 0 144 165 240 ];
          fps_limit_method = "late";
          vsync = 2;
          gl_vsync = 1;
          toggle_hud = "Shift_R+F12";
          toggle_fps_limit = "Shift_R+F1";
          fps = true;
          frametime = true;
          cpu_stats = true;
          cpu_temp = true;
          gpu_stats = true;
          gpu_temp = true;
          vram = true;
          ram = true;
        };
      };
    })
  ];
}