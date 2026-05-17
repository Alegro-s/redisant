-- ============================================================================
-- NEXUS · стартовый скрипт для обучающего пакета Tetris (логика на Lua, не отдельный режим движка)
-- ============================================================================
-- Копия для репозитория; bundle: assets/engine_templates/tetris_starter.lua (rootBundle).
-- ============================================================================

local function log(msg)
  nexus_log("[tetris] " .. tostring(msg))
end

function on_start()
  log("Шаблон Tetris: заполните матрицу, ввод (key_a/key_d/key_s) и таймер шага.")
end

function on_update(dt)
  -- dt — секунды; пример: накопление времени для гравитации фигуры
end

return {
  on_start = on_start,
  on_update = on_update,
}
