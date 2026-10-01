-- Nebula OS: візуальний tweaking Hyprland (blur/анімації/border/rounding/gaps).
-- Живий файл, окремо від hyprland.lua саме для того, щоб можна було
-- експериментувати з виглядом (вручну або через GZML пізніше, якщо
-- підтвердиться Lua-хук), не чіпаючи базовий конфіг.

hl.curve("nebula", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

-- render.direct_scanout=false -- 2026-09-30, живо впіймано: коли на виводі
-- лишається рівно один fullscreen/єдиний клієнт (або взагалі жоден звичайний
-- клієнт, лише фонова шейдер-шпалера з nebula-space-wallpaper-wl), Hyprland
-- заради продуктивності жене його буфер напряму в KMS, оминаючи спільний
-- render-буфер, який читає screencopy/PipeWire -- звідси чорний екран у
-- трансляції (і локально, і в глядача), де реально домальовується ЛИШЕ
-- курсор (Hyprland 0.56.2 додав коректне курсор-накладання поверх direct
-- scanout окремим шляхом, тому решта кадру лишається чорною, а курсор -- ні).
-- Підтверджено живо: на робочому столі, де кілька вікон одночасно (звичайний
-- compositing, scanout не застосовується), трансляція нормальна.
hl.config({
  render = {
    direct_scanout = false,
  },
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
    layout = "dwindle",
    col = {
      active_border = "rgba(cba6f7ff)",
      inactive_border = "rgba(313244ff)",
    },
  },
  decoration = {
    rounding = 10,
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      new_optimizations = true,
    },
  },
})

-- hyprland-scroll-overview (SUPER+O у hyprland.lua) -- niri-стиль огляду
-- робочих просторів. blur=true -- розмиває тільки фонову шпалеру огляду
-- (узгоджено з decoration.blur вище), wallpaper=2 -- показує і глобальну, і
-- per-workspace шпалеру, якщо колись з'являться окремі шпалери на воркспейс
-- (зараз лише глобальна через nebula-space-wallpaper-wl, тож ефекту не дає,
-- але не шкодить лишити дефолт).
hl.config({
  plugin = {
    scrolloverview = {
      gesture_distance = 300,
      scale = 0.5,
      workspace_gap = 100,
      layout = "auto",
      wallpaper = 2,
      blur = true,
    },
  },
})

hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "nebula" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "nebula" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "nebula" })
