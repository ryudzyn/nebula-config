{ pkgs, ... }:
{
  programs.btop = {
    enable = true;
    package = pkgs.btop.override { rocmSupport = true; }; # rocm — бо в тебе AMD, не CUDA
  };
  programs.cava.enable = true;
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.fastfetch.enable = true;
  programs.lazygit.enable = true;
  programs.tmux = {
    enable = true;
    clock24 = true;
    keyMode = "vi";
  };
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";
  };
  programs.thunderbird.enable = true;
}