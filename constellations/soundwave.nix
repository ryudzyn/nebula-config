{ config, pkgs, ... }:
{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true; # JACK-сумісність -- потрібна ardour/lmms (core/packages.nix, аудіопродакшн)

    # Буфер: типово 1024 (~21мс), дозволено 256..2048. Раніше був жорстко 256 (min = max)
    # заради ardour -- браузер не міг взяти більший, і під навантаженням (дзвінок у Zen +
    # Sunshine/локальна модель) голос у Telegram Web рвався: underrun/timeout у pipewire-pulse
    # (2026-11-14). Ardour і далі просить 256 через JACK -- граф підлаштовується під нього.
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 256;
        "default.clock.max-quantum" = 2048;
      };
    };
    # Мікрофон у PCM2902 підключений лише в лівий вхід: правий канал -- тиша (-87 дБ). Застосунки
    # зводили «стерео» в моно, голос ставав удвічі тихшим, а шумодав/автопідсилення браузера
    # робили з нього «бочку». Окреме моно-джерело лише з лівого каналу, типове для всіх.
    extraConfig.pipewire."94-mic-mono" = {
      "context.modules" = [
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.description" = "Мікрофон (моно)";
            "capture.props" = {
              "node.name" = "capture.mic_mono";
              "audio.position" = [ "FL" ];
              "stream.dont-remix" = true;
              "target.object" = "alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo-input";
              "node.passive" = true;
            };
            "playback.props" = {
              "node.name" = "mic_mono";
              "node.description" = "Мікрофон (моно)";
              "media.class" = "Audio/Source";
              "audio.position" = [ "MONO" ];
              # вище за звичайні ALSA-джерела (~2000) -- WirePlumber бере його типовим
              "priority.session" = 2100;
            };
          };
        }
      ];
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
            "audio.position" = [
              "FL"
              "FR"
            ];
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
            pulse.default.req = "1024/48000";
            pulse.max.req = "2048/48000";
          };
        }
      ];
    };
  };
}
