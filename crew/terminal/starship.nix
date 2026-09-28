{ lib, ... }:
{
  # Розширене налаштування prompt'у -- саме увімкнення (programs.starship.enable)
  # лишається в ./zsh.nix, тут лише settings. Кольори -- та сама палітра
  # (accent #9d4edd/mauve, bg #1a1a2e), що в polybar/dunst (crew/bspwm.nix),
  # щоб термінал не випадав зі стилю решти десктопу.
  programs.starship.settings = {
    add_newline = false;
    format = lib.concatStrings [
      "$directory"
      "$git_branch"
      "$git_status"
      "$nix_shell"
      "$cmd_duration"
      "$line_break"
      "$character"
    ];

    character = {
      success_symbol = "[❯](bold #9d4edd)";
      error_symbol = "[❯](bold #e05561)";
    };

    directory = {
      style = "bold #c9b8ff";
      truncation_length = 3;
      truncate_to_repo = true;
    };

    git_branch = {
      style = "#9d4edd";
      symbol = " ";
      format = "[on](white) [$symbol$branch]($style) ";
    };

    git_status = {
      style = "#e05561";
      format = "([$all_status$ahead_behind]($style)) ";
    };

    nix_shell = {
      symbol = " ";
      style = "bold #88c0d0";
      format = "[$symbol$state]($style) ";
    };

    cmd_duration = {
      min_time = 2000;
      style = "#888888";
      format = "took [$duration]($style) ";
    };
  };
}
