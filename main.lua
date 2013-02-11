-- entrance point for löve2d not much happening here

function clamp(min,val,max)
  return math.min(max,math.max(min,val))
end

  
function super(self)
	return getmetatable(assert(getmetatable(self)).__index).__index
end

function init_world()
  -- ini
  dofile "world/world_init.lua"
end

function love.load()
  init_world()
end

function love.draw()
  world_state:draw()
  world_state:step()
  io.flush()
end

function love.keypressed(key)
  if key == "escape" then os.exit() end
  if key == "f5" then
    init_world()
  end
  if key == "f1" then
    world_state:toggle_draw_debug_info()
  end
  
  if key == "up" then world_state:change_steps(1) end
  if key == "down" then world_state:change_steps(-1) end
end