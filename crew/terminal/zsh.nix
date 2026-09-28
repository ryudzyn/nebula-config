{ pkgs, config, ... }:
{
  programs.zsh = {
    enable = true;
    history = {
      size = 100000;
      path = "${config.xdg.dataHome}/zsh/history";
    };
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      l = "${pkgs.eza}/bin/eza -lh --icons=auto";
      ll = "${pkgs.eza}/bin/eza -lha --icons=auto --sort=name --group-directories-first";
      cls = "clear";
      sysup = "nh os switch ~/nebula-config"; # застосувати цей флейк (nixos-rebuild switch під капотом)
    };
  };

  programs.starship.enable = true;
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}