{ pkgs, config, ... }:
{
  # Ретранслятор стріму зі звуком гри (assets/stream-relay.html, TODO.md #56)
  # віддається через http://127.0.0.1:8787, а не file://. Для file:// Chromium
  # (Vivaldi) не запам'ятовує дозвіл на "мікрофон", а коли доступ видає
  # політика, ховає список пристроїв -- сторінка бачила лише один "(без назви)"
  # замість "Звук гри (для трансляції)" (відтворено з чистим профілем). З
  # http://127.0.0.1 дозвіл питається раз і запам'ятовується, назви пристроїв
  # видно. Лише localhost; каталог -- живий assets у чекауті, тож правки
  # сторінки видно одразу.
  systemd.user.services.nebula-stream-relay = {
    Unit.Description = "Nebula: local web server for the game-audio stream relay page";
    Service = {
      ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8787 --bind 127.0.0.1 --directory ${config.home.homeDirectory}/nebula-config/assets";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
