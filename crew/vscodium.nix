{ pkgs, ... }:
{
  programs.vscodium = {
    enable = true;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      ms-azuretools.vscode-docker
      redhat.vscode-yaml
      jnoortheen.nix-ide # підсвітка/LSP для .nix-файлів -- цього ж репо
      ms-vscode-remote.remote-ssh
      eamodio.gitlens
      mkhl.direnv # автопідхоплення .envrc/nix develop-оточень у редакторі
    ];
  };
}