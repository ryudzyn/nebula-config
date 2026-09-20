{ ... }:
{
  # "Nebula (base16)" — реальна вбудована схема WezTerm (base16-nebula-scheme),
  # найближче влучає в назву проєкту з усіх пресетів, що йдуть у комплекті.
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      return {
        color_scheme = "Nebula (base16)",
        font = wezterm.font("JetBrainsMono Nerd Font"),
        font_size = 11.0,
        hide_tab_bar_if_only_one_tab = true,
        window_background_opacity = 0.92,
      }
    '';
  };
}
