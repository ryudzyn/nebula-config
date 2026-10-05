{ config, pkgs, ... }:
{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true; # JACK-сумісність -- потрібна ardour/lmms (core/packages.nix, аудіопродакшн)

    # Малий буфер (256 фреймів @ 48kHz ≈ 5.3мс) замість дефолтного -- нижча
    # затримка для живого запису/моніторингу в ardour, ціна -- вищий ризик
    # xrun'ів на важкому навантаженні (прийнятно для цього заліза).
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 256;
        "default.clock.min-quantum" = 256;
        "default.clock.max-quantum" = 256;
      };
    };
    # Звук гри для трансляції через браузер (2026-10-04, assets/stream-relay.html):
    # віртуальний вихід "Гра → трансляція" (гру спрямовуєш сюди в pavucontrol) і
    # те саме аудіо як віртуальне джерело "Звук гри (для трансляції)", яке
    # сторінка-ретранслятор бере через getUserMedia. Так у стрім іде лише гра, без
    # голосів з Discord (живо перевірено: Chromium бачить це джерело).
    extraConfig.pipewire."93-nebula-game-stream" = {
      "context.modules" = [
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.description" = "Гра → трансляція";
            "audio.position" = [ "FL" "FR" ];
            "capture.props" = {
              "node.name" = "nebula_game_stream";
              "node.description" = "Гра → трансляція";
              "media.class" = "Audio/Sink";
            };
            "playback.props" = {
              "node.name" = "nebula_game_source";
              "node.description" = "Звук гри (для трансляції)";
              "media.class" = "Audio/Source";
            };
          };
        }
      ];
    };
    extraConfig.pipewire-pulse."92-low-latency" = {
      context.modules = [
        {
          name = "libpipewire-module-protocol-pulse";
          args = {
            pulse.min.req = "256/48000";
            pulse.default.req = "256/48000";
            pulse.max.req = "256/48000";
          };
        }
      ];
    };
  };
}