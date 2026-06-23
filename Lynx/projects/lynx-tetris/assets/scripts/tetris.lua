-- Lynx Tetris — portrait 480×640, logic grid display (wave 15: btn_pressed / ghost)
local W, H = 10, 20

-- vars(0,0) phase: 0=menu, 1=play, 2=gameover
-- vars(0,1) piece type, (0,2) rot, (0,3) px, (0,4) py
-- vars(0,5) gravity ms acc, (0,6) score, (0,7) lines, (0,8) rng

local shapes = {
  { {0,0,0,0}, {1,1,1,1}, {0,0,0,0}, {0,0,0,0} },
  { {2,2}, {2,2} },
  { {0,3,0}, {3,3,3}, {0,0,0} },
  { {0,4,4}, {4,4,0}, {0,0,0} },
  { {5,5,0}, {0,5,5}, {0,0,0} },
  { {6,0,0}, {6,6,6}, {0,0,0} },
  { {0,0,7}, {7,7,7}, {0,0,0} },
}

local function vget(x, y) return grid_get("vars", x, y) end
local function vset(x, y, val) grid_set("vars", x, y, val) end

local function shape_size(t)
  local s = shapes[t]
  if not s then return 0 end
  return #s
end

local function rot_cell(m, r, x, y, size)
  if not m or size <= 0 then return 0 end
  local ox, oy = x, y
  if r == 1 then
    ox, oy = y, size - 1 - x
  elseif r == 2 then
    ox, oy = size - 1 - x, size - 1 - y
  elseif r == 3 then
    ox, oy = size - 1 - y, x
  end
  local row = m[oy + 1]
  if not row then return 0 end
  return row[ox + 1] or 0
end

local function collides(px, py, t, r)
  if not shapes[t] or shape_size(t) == 0 then return true end
  local sz = shape_size(t)
  for y = 0, sz - 1 do
    for x = 0, sz - 1 do
      local v = rot_cell(shapes[t], r, x, y, sz)
      if v > 0 then
        local bx, by = px + x, py + y
        if bx < 0 or bx >= W or by >= H then return true end
        if by >= 0 and grid_get("board", bx, by) > 0 then return true end
      end
    end
  end
  return false
end

local function stamp_board(px, py, t, r)
  local sz = shape_size(t)
  for y = 0, sz - 1 do
    for x = 0, sz - 1 do
      local v = rot_cell(shapes[t], r, x, y, sz)
      if v > 0 then
        local bx, by = px + x, py + y
        if by >= 0 and by < H and bx >= 0 and bx < W then
          grid_set("board", bx, by, v)
        end
      end
    end
  end
end

local function clear_lines()
  local cleared = 0
  for y = H - 1, 0, -1 do
    local full = true
    for x = 0, W - 1 do
      if grid_get("board", x, y) == 0 then full = false break end
    end
    if full then
      cleared = cleared + 1
      for yy = y, 1, -1 do
        for x = 0, W - 1 do
          grid_set("board", x, yy, grid_get("board", x, yy - 1))
        end
      end
      for x = 0, W - 1 do grid_set("board", x, 0, 0) end
      y = y + 1
    end
  end
  if cleared > 0 then
    local bonus = ({0, 100, 300, 500, 800})[cleared + 1] or 800
    vset(0, 6, vget(0, 6) + bonus)
    vset(0, 7, vget(0, 7) + cleared)
  end
end

local function reset_board()
  grid_fill("board", 0)
  vset(0, 5, 0)
  vset(0, 6, 0)
  vset(0, 7, 0)
end

local function spawn_piece()
  local seed = vget(0, 8) + 17
  vset(0, 8, seed)
  local t = (seed % 7) + 1
  vset(0, 1, t)
  vset(0, 2, 0)
  vset(0, 3, 3)
  vset(0, 4, 0)
  if collides(vget(0, 3), vget(0, 4), t, 0) then
    vset(0, 0, 2)
  end
end

local function start_game()
  reset_board()
  vset(0, 0, 1)
  spawn_piece()
end

local function ghost_drop_y(px, py, t, r)
  while not collides(px, py + 1, t, r) do
    py = py + 1
  end
  return py
end

local function stamp_piece_on_display(px, py, t, r, ghost)
  local sz = shape_size(t)
  for y = 0, sz - 1 do
    for x = 0, sz - 1 do
      local v = rot_cell(shapes[t], r, x, y, sz)
      if v > 0 then
        local bx, by = px + x, py + y
        if bx >= 0 and bx < W and by >= 0 and by < H then
          local cell = ghost and (v + 100) or v
          grid_set("display", bx, by, cell)
        end
      end
    end
  end
end

local function rebuild_display()
  grid_fill("display", 0)
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local v = grid_get("board", x, y)
      if v > 0 then grid_set("display", x, y, v) end
    end
  end
  if vget(0, 0) == 1 then
    local t, r, px, py = vget(0, 1), vget(0, 2), vget(0, 3), vget(0, 4)
    local gy = ghost_drop_y(px, py, t, r)
    if gy ~= py then
      stamp_piece_on_display(px, gy, t, r, true)
    end
    stamp_piece_on_display(px, py, t, r, false)
  end
end

local function try_move(dx, dy)
  if vget(0, 0) ~= 1 then return false end
  local px, py = vget(0, 3) + dx, vget(0, 4) + dy
  local t, r = vget(0, 1), vget(0, 2)
  if not collides(px, py, t, r) then
    vset(0, 3, px)
    vset(0, 4, py)
    return true
  end
  return false
end

local function try_rotate()
  if vget(0, 0) ~= 1 then return end
  local t = vget(0, 1)
  if not shapes[t] then return end
  local r = (vget(0, 2) + 1) % 4
  local px, py = vget(0, 3), vget(0, 4)
  local kicks = {0, -1, 1, -2, 2}
  for i = 1, #kicks do
    local kx = kicks[i]
    if not collides(px + kx, py, t, r) then
      vset(0, 3, px + kx)
      vset(0, 2, r)
      return
    end
  end
end

local function lock_piece()
  stamp_board(vget(0, 3), vget(0, 4), vget(0, 1), vget(0, 2))
  clear_lines()
  spawn_piece()
end

local function step_gravity()
  if vget(0, 0) ~= 1 then return end
  if not try_move(0, 1) then lock_piece() end
end

local function held_left()
  return key_left or key_a or gp_dleft
end

local function held_right()
  return key_right or key_d or gp_dright
end

local function held_soft_drop()
  return key_down or key_s or gp_ddown
end

if grid_width("vars") == 0 then
  grid_ensure("board", W, H)
  grid_ensure("display", W, H)
  grid_ensure("vars", 1, 12)
  grid_fill("board", 0)
  vset(0, 0, 0)
  vset(0, 8, 1)
  nexus_log("Tetris: тап / A — старт · D-pad · ⟳ поворот · ↓ сброс")
end

local phase = vget(0, 0)

if phase == 0 then
  if btn_pressed("a") or btn_pressed("enter") or action_pressed("rotate") then
    start_game()
  end
elseif phase == 1 then
  if held_left() then try_move(-1, 0) end
  if held_right() then try_move(1, 0) end
  if btn_pressed("up") or btn_pressed("a") or action_pressed("rotate") then
    try_rotate()
  end
  if held_soft_drop() or action_pressed("soft_drop") then step_gravity() end
  if btn_pressed("b") or btn_pressed("enter") or action_pressed("hard_drop") then
    while try_move(0, 1) do end
    lock_piece()
  end
  local acc = vget(0, 5) + dt * 1000
  local interval = math.max(100, 650 - vget(0, 7) * 10)
  if acc >= interval then
    acc = 0
    step_gravity()
  end
  vset(0, 5, acc)
elseif phase == 2 then
  if btn_pressed("a") or btn_pressed("enter") then
    vset(0, 0, 0)
    reset_board()
  end
end

rebuild_display()
