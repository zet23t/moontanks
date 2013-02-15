 --[[
 Some useful utility functions for AI
 ]]

--- Calculates the distance between two points.
function dist(x1,y1,x2,y2)
  local dx,dy = x1-x2,y1-y2
  return (dx*dx+dy*dy)^.5
end

--- Sorts a list of tanks by their distance to a given x,y point.
function tanks_by_dist(x,y,tanks)
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

function aim_and_shoot_at(tx,ty,shoot_angle_threshold)
  local dx,dy = tx-x,ty-y
  local sqdist = dx*dx+dy*dy
  if sqdist > 0 then
    local dist = sqdist^.5
    local dir_x,dir_y = math.cos(bearing),math.sin(bearing)
    dx,dy = dx / dist, dy / dist
    local dot = -dx*dir_y+dy*dir_x
    set_desired_bearspeed(dot)
    if math.abs(dot) < (shoot_angle_threshold or .05) then shoot() end
    return dist
  end
  return 0
end

function aim_with_prediction_and_shoot (shootat)
  local speed_fac = 1 / constant.PROJECTILE_SPEED 
  local enemy_dirx, enemy_diry = math.cos(shootat.dir),math.sin(shootat.dir)
  local targetdist = dist(shootat.x,shootat.y,x,y)
  local movespeed = shootat.movespeed
  local x,y = shootat.x + enemy_dirx * targetdist * movespeed * speed_fac, 
    shootat.y + enemy_diry * targetdist * movespeed * speed_fac
  aim_and_shoot_at(x,y)
end

-- Sets desired turn and movespeed to move towards the given point
function driveto(to_x,to_y)
  local dx,dy = to_x-x,to_y-y
  local dir_x,dir_y = math.cos(dir),math.sin(dir)
  local dot = dir_x * dy - dir_y * dx
  set_desired_turnspeed(dot)
  set_desired_movespeed(1)
end
