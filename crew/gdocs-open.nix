{ pkgs, ... }:
let
  # Документи ведуться в Google Docs, офісного пакета в системі немає: подвійний клік по
  # локальному файлу відкриває Drive у браузері й показує файл у Nemo, лишається перетягнути.
  # Самого завантаження тут нема: для нього потрібен був би окремий доступ до Drive.
  nebula-gdocs-open = pkgs.writeShellScriptBin "nebula-gdocs-open" ''
    ${pkgs.xdg-utils}/bin/xdg-open "https://drive.google.com/drive/my-drive" >/dev/null 2>&1 &
    for file in "$@"; do
      nemo "$file" >/dev/null 2>&1 &
    done
  '';
in
{
  home.packages = [ nebula-gdocs-open ];

  # Типовою програмою її робить ~/.config/mimeapps.list, він не під Home Manager
  xdg.desktopEntries.nebula-gdocs = {
    name = "Google Docs";
    comment = "Відкрити Google Drive і показати файл у Nemo";
    exec = "nebula-gdocs-open %F";
    icon = "google-docs";
    terminal = false;
    noDisplay = true;
    mimeType = [
      "application/msword"
      "application/vnd.ms-excel"
      "application/vnd.ms-powerpoint"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      "application/vnd.oasis.opendocument.text"
      "application/vnd.oasis.opendocument.spreadsheet"
      "application/vnd.oasis.opendocument.presentation"
    ];
  };
}
