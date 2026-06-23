-- Lynx TIC API — persistent TIC() callback (TIC-80 style)
local t = 0

function BOOT()
  music(0)
end

function TIC()
  t = t + 1
  cls(1)
  map(0, 0, 30, 17, 0, 0, 1)
  local px = 120 + math.floor(math.sin(t / 18) * 50)
  spr(1, px, 60, 0, 1, 1, 1, 8, 8, 1, 0)
  print("TIC STARTER", 8, 8, 15)
  if btn(4) or btnp(4) then
    sfx(0, 48, 8, 0, 15, 0)
  end
end
