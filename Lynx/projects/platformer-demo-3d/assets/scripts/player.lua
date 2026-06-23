-- Platformer demo (wave 0)
local speed = 260
local jump = 520
local nvx = 0
local nvy = vy

if key_a then nvx = -speed end
if key_d then nvx = speed end
if not key_a and not key_d then nvx = 0 end
if key_space and on_ground then nvy = -jump end
set_velocity(nvx, nvy)
