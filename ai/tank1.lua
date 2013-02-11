--[[

Very simple AI. Available variables (updated each round)

bearing = where the gun is pointing to (radians, world coordinates)
dir = where the tank is driving to (radians, world coordinates)
movespeed = speed at which the tank is driving right now
turnspeed = speed at which the tank is turning around right now
bearspeed = speed at which the barrel is turning around right now
remaining_reloadtime = how much time is left until the tank can shoot again
x,y = world coordinates of myself
othertanks = list of other tanks
MAP_WIDTH,MAP_HEIGHT = size of map

]]

local turndir = 1 --math.random() > .5 and 1 or -1
local frame = 0
while true do
  frame = frame + 1
  set_desired_turnspeed(math.random()-.5)
  set_desired_movespeed(1)
  
  local function dist_to(X,Y)
    local dx,dy = X-x,Y-y
    return (dx*dx+dy*dy)^.5
  end
  
  local enemy = nil
  local dist = nil
  
  for i=1,#othertanks do
    local other =othertanks[i]
    if other.team ~= team then
      local dist2 = dist_to(other.x,other.y)
      if not enemy or dist2 < dist then dist,enemy = dist2,other end
    end
  end
  
  local dirx,diry = math.cos(dir),math.sin(dir)
    
    
  if enemy then
    local dx,dy = enemy.x-x,enemy.y-y
    local bx,by = math.cos(bearing),math.sin(bearing)
    local dist = (dx*dx+dy*dy)^.5
    if dist > 0 then
      local enemy_dirx, enemy_diry = math.cos(enemy.dir), math.sin(enemy.dir)
      do
        local speed_fac = 1 / constant.PROJECTILE_SPEED 
        local dx,dy = dx + enemy_dirx * dist * enemy.movespeed * speed_fac, dy + enemy_diry * dist * enemy.movespeed * speed_fac
        local dist = (dx*dx+dy*dy)^.5
        dx,dy = dx / dist, dy / dist
        local dot = dx * by - dy * bx
        set_desired_bearspeed(-dot)
      end
      --print(dist)
      dx,dy = dx / dist, dy / dist
      
      
      if dx*dirx+dy*diry > 0.5 then
        if dist < 50 then 
          set_desired_turnspeed(0) 
        elseif dist > 100 then 
       --   print("?",frame)
          set_desired_turnspeed((dx*dirx+dy*diry) * turndir * 2)
        end
      else
        if dist > 200 then
          set_desired_turnspeed((dx*diry-dy*dirx) * -turndir)
        else 
          --set_desired_turnspeed((dx*diry-dy*dirx) * -turndir)
          set_desired_turnspeed(0)
        end
        
      end
      --drawrect(enemy.x,enemy.y,4,4,255,0,0)
      if dist < 250 then
        shoot()
      end
    end
  end
  
  if x < 50 and dirx < .25 then set_desired_turnspeed(turndir) end
  if x > MAP_WIDTH-50 and dirx > -.25 then set_desired_turnspeed(turndir) end
  if y < 50 and diry < .25 then set_desired_turnspeed(turndir) end
  if y > MAP_HEIGHT-50 and diry > -.25 then set_desired_turnspeed(turndir) end
  
  wait()
end