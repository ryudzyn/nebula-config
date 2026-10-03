{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    lutris # менеджер non-Steam ігор (GOG/Epic через плагіни, кастомні wine-префікси)
    heroic # нативний лаунчер GOG/Epic Games Store
    bottles # окремі wine-контейнери під конкретні Windows-застосунки, не лише ігри
    ryubing # емулятор Nintendo Switch (форк Ryujinx)
    wineWow64Packages.staging # wine з ще не змерджиними в stable патчами -- ширша сумісність
    gamescope
  ];

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