{ inputs, config, ... }:
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    # Автозапуск через systemd --user, прив'язаний до wayland.systemd.target —
    # той самий графічний таргет, який Hyprland сам активує при старті сесії.
    systemd.enable = true;
    # settings навмисно НЕ використовується: той шлях (xdg.configFile через
    # generateToml) пише в /nix/store і конфліктував би з живим symlink'ом
    # нижче. config.toml лишається чистим hand-written файлом у репо.
  };

  # ~/.config/noctalia/config.toml — hand-written шар (див. сам файл),
  # той самий mkOutOfStoreSymlink-підхід, що й для Hyprland.
  home.file.".config/noctalia/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nebula-config/crew/noctalia/config.toml";
}
