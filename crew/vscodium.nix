{ pkgs, ... }:
{
  programs.vscodium = {
    enable = true;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      ms-azuretools.vscode-docker
      redhat.vscode-yaml
      jnoortheen.nix-ide
      ms-vscode-remote.remote-ssh
      eamodio.gitlens
      mkhl.direnv
    ];
  };
}