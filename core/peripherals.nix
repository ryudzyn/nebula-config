{ config, pkgs, lib, ... }:
{
  # nix-ld -- дозволяє запускати НЕ-Nix-збірені бінарники (закачані appimage,
  # чужі .deb-розпаковки, IDE-плагіни з власними бінарями тощо) через
  # підмінений динамічний лінкер, який шукає ці бібліотеки за стандартними
  # шляхами замість жорсткого /nix/store-хеша, вшитого в NixOS-збірки.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      libx11
      libxext
      libxrender
      libxi
      libxrandr
      libxfixes
      libxcursor
      libsm
      libice
      libxcb
      libxcb-util
      libxcb-image
      libxcb-keysyms
      libxcb-render-util
      libxcb-wm
      fontconfig
      freetype
      glib
      libGL
      zlib
      dbus
      krb5
      libxkbcommon
      openssl
      wayland
      alsa-lib
      libudev0-shim
    ];
  };

  # Swiftpoint-миша (Z/Z2/Z3, звичайний і bootloader-режим для прошивки) та
  # Kinetis-bootloader -- без MODE="0666" ці hidraw-пристрої доступні тільки
  # root, тож Swiftpoint Control Panel не зміг би до них
  # достукатись з-під звичайного юзера.
  services.udev.extraRules = ''
    KERNEL=="hidraw*", ATTRS{idVendor}=="214e", ATTRS{idProduct}=="0005", MODE="0666", TAG+="Swiftpoint_Z"
    KERNEL=="hidraw*", ATTRS{idVendor}=="214e", ATTRS{idProduct}=="0007", MODE="0666", TAG+="Swiftpoint_Z Bootloader"
    KERNEL=="hidraw*", ATTRS{idVendor}=="15a2", ATTRS{idProduct}=="0073", MODE="0666", TAG+="Kinetis_Bootloader"
    KERNEL=="hidraw*", ATTRS{idVendor}=="214e", ATTRS{idProduct}=="000a", MODE="0666", TAG+="Creator"
    KERNEL=="hidraw*", ATTRS{idVendor}=="214e", ATTRS{idProduct}=="0014", MODE="0666", TAG+="Tracer"
    KERNEL=="hidraw*", ATTRS{idVendor}=="214e", ATTRS{idProduct}=="001e", MODE="0666", TAG+="Swiftpoint_Z2"
    KERNEL=="hidraw*", ATTRS{idVendor}=="214e", ATTRS{idProduct}=="0031", MODE="0666", TAG+="Swiftpoint_Z3_Dongle Bootloader"
    KERNEL=="hidraw*", ATTRS{idVendor}=="214e", ATTRS{idProduct}=="0032", MODE="0666", TAG+="Swiftpoint_Z3_Dongle"
    KERNEL=="hidraw*", ATTRS{idVendor}=="214e", ATTRS{idProduct}=="0033", MODE="0666", TAG+="Swiftpoint_Z3_Mouse Bootloader"
    KERNEL=="hidraw*", ATTRS{idVendor}=="214e", ATTRS{idProduct}=="0034", MODE="0666", TAG+="Swiftpoint_Z3_Mouse"
    SUBSYSTEM=="hidraw", KERNELS=="0005:214E:0035*", MODE="0666", TAG+="Swiftpoint_Z3_BTLE_Mouse"
    KERNEL=="event*", SUBSYSTEM=="input", TAG+="uaccess"
    KERNEL=="hiddev*", ATTRS{idVendor}=="214e", MODE="0666"
  '';

  
}