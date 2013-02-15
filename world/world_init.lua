-- these constants are available in the AI scripts
constant = {
  PROJECTILE_SPEED = 3;
  TANK_RADIUS = 8;
  MAP_WIDTH = love.graphics.getWidth();
  MAP_HEIGHT = love.graphics.getHeight();
  MAX_TURNSPEED = .04;
  MAX_BEARSPEED = .08;
}
-- load the files we need to run the game
dofile "world/util.lua"
dofile "world/tank.lua"
dofile "world/tankworld.lua"

-- create our default world state and initialize it
world_state = world:create()
ais = {
  "ai/tank1.lua",
  "ai/tank4.lua",
  "ai/tank2.lua",
  "ai/tank3.lua",
 }
for i=1,#ais do
  local team = i*.05
  local cx = 100 + (i-1)*(love.graphics.getWidth()-100)/#ais
  local cy = 50
  local ai = ais[i]
  for ti=1,8 do
    world_state:add_tank(tank:create(world_state,ai,team )
    :set_xy(math.random() * 0 + cx + math.floor(ti / 10) * 40,cy + (ti%10) * 40)
    :set_dir(math.pi/2)
    :set_bearing(math.pi/2))
  end
end
world_state.draw_debug_info = true