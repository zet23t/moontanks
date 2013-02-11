local function dist(x1,y1,x2,y2)
  local dx,dy = x1-x2,y1-y2
  return (dx*dx+dy*dy)^.5
end

local function other_tanks_by_dist(x,y,tanks)
  local list = {}
  tanks = tanks or othertanks
  for i=1,#tanks do
    local tank = tanks[i]
    tank.dist = dist(tank.x,tank.y,x,y)
    list[i] = tank
  end
  table.sort(list,function(a,b) return a.dist < b.dist end)
  return list
end

local function copy(tab)
  local t = {}
  for i,v in pairs(tab) do t[i] = v end
  return t
end

local function aim_and_shoot_at(tx,ty)
  local dx,dy = tx-x,ty-y
  local sqdist = dx*dx+dy*dy
  if sqdist > 0 then
    local dist = sqdist^.5
    local dir_x,dir_y = math.cos(bearing),math.sin(bearing)
    dx,dy = dx / dist, dy / dist
    local dot = -dx*dir_y+dy*dir_x
    set_desired_bearspeed(dot)
    if math.abs(dot) < .05 then shoot() end
    return dist
  end
  return 0
end

local function aim_with_prediction_and_shoot (shootat)
  local speed_fac = 1 / constant.PROJECTILE_SPEED 
  local enemy_dirx, enemy_diry = math.cos(shootat.dir),math.sin(shootat.dir)
  local targetdist = dist(shootat.x,shootat.y,x,y)
  local movespeed = shootat.movespeed
  local x,y = shootat.x + enemy_dirx * targetdist * movespeed * speed_fac, 
    shootat.y + enemy_diry * targetdist * movespeed * speed_fac
  aim_and_shoot_at(x,y)
end


while true do
  -- avoid the most closest tanks. We also want to avoid walls pretty equally.
  -- Thus, we search the closest tank from the list of all tanks. To avoid
  -- the walls, we add "virtual" tanks that are scaring us away from the walls.
  local virtual_list = copy(othertanks)
  virtual_list[#virtual_list+1] = {x = x, y = -5, team = team}
  virtual_list[#virtual_list+1] = {x = x, y = MAP_HEIGHT+5, team = team}
  virtual_list[#virtual_list+1] = {x = -5, y = y, team = team}
  virtual_list[#virtual_list+1] = {x = MAP_WIDTH+5, y = y, team = team}
  
  local tanks_by_dist = other_tanks_by_dist(x,y,virtual_list)
  local tank_avoid = tanks_by_dist[1]
  if tank_avoid then
    local dx,dy = tank_avoid.x-x,tank_avoid.y-y
    local dir_x,dir_y = math.cos(dir),math.sin(dir)
    local dot = dir_x * dy - dir_y * dx
    set_desired_turnspeed(-dot)
    set_desired_movespeed(1)
  end
  
  -- we can now shoot at the closest enemy by search through the list we compiled
  for i=1,#virtual_list do 
    local opponent = tanks_by_dist[i]
    if opponent.team ~= team then
      -- don't shoot if the opponent is too far away
      if opponent.dist > 350 then break end
      aim_with_prediction_and_shoot(opponent)
      --drawline(x,y,opponent.x,opponent.y,255,0,0)
      break
    end
  end
  
  
  
  wait()
end
