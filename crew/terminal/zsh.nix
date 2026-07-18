{ pkgs, config, ... }:
{
  programs.zsh = {
    enable = true;
    history = {
      size = 100000;
      path = "${config.xdg.dataHome}/zsh/history";
    };
    autosuggestion.enable = true; # Вмикаємо стандартно, але ми пришвидшимо це через defer
    syntaxHighlighting.enable = true;
    
    shellAliases = {
      l = "${pkgs.eza}/bin/eza -lh --icons=auto";
      ll = "${pkgs.eza}/bin/eza -lha --icons=auto --sort=name --group-directories-first";
      cls = "clear";
      sysup = "nh os switch ~/nebula-config"; # Твоя нова команда для оновлення галактики
    };

    initContent = ''
     eval "$(starship init zsh)"
     eval "$(zoxide init zsh)"
   '';
  };
}