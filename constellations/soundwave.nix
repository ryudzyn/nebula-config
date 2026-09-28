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