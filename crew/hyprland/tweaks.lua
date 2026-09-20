-- Nebula OS: візуальний tweaking Hyprland (blur/анімації/border/rounding/gaps).
-- Живий файл, окремо від hyprland.lua саме для того, щоб можна було
-- експериментувати з виглядом (вручну або через GZML пізніше, якщо
-- підтвердиться Lua-хук), не чіпаючи базовий конфіг.

hl.curve("nebula", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.config({
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

hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "nebula" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "nebula" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "nebula" })
