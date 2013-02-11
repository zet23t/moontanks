while true do
  local random_turndir = .01
  function pick_random_dir()
    if math.random()>.95 then random_turndir = math.random()*.2-.1 end
    set_desired_turnspeed(random_turndir)
  end
  
  pick_random_dir()
  set_desired_movespeed(1)
  
  function avoid_borders(turndir)
    local dirx,diry = math.cos(dir), math.sin(dir)
    local MINDIST = 100
    local is_close = 
      (x < MINDIST and dirx < .25) or 
      (y < MINDIST and diry < .25) or 
      (x > MAP_WIDTH-MINDIST and dirx > -.25) or
      (y > MAP_HEIGHT-MINDIST and diry > -.25)
    if is_close then
      turndir = turndir or (math.random() > .5 and 1 or -1)
      set_desired_turnspeed(turndir)
      wait()
      return avoid_borders(turndir)
    end
  end
  
  function find_closest_tank (matcher,...)
    local closest_dist, closest_tank
    for i=1,#othertanks do
      local tank = othertanks[i]
      local dx,dy = tank.x - x, tank.y - y
      local dist = (dx*dx+dy*dy)
      if matcher(tank,...) and (not closest_dist or dist < closest_dist) then
        closest_tank,closest_dist = tank,dist
      end
    end
    return closest_tank,closest_dist
  end
  
  function matcher_team(tank,friendly) return (tank.team == team) == friendly end
  
  function avoid_team()
    local other, dist = find_closest_tank(matcher_team,true)
    drawcircle(x,y,50,255,0,0) 
    local MAXMINDIST = 30
    if other and dist < MAXMINDIST*MAXMINDIST then
      --print "avoiding"
      repeat
        local dx,dy = other.x - x, other.y - y
        drawcircle(x,y,200,255,0,0)
        dist = (dx*dx+dy*dy)^.5
        local dirx,diry = math.cos(dir), math.sin(dir)
        if dirx*dy - diry*dx > -0.75 then
          pick_random_dir()
        else
          set_desired_turnspeed(1)
        end
        drawline(x,y,other.x,other.y,255,0,0)
        avoid_borders()
        wait()
      until dist > MAXMINDIST*2 or other.hitpoints == 0
      --print "avoided"
    end
  end
  
  function fight_closeby_enemies()
    local other, dist = find_closest_tank(matcher_team,false)
    local maxdist = 500
    if other and dist < maxdist*maxdist then
      --repeat
        local dx,dy = other.x - x, other.y - y
        local targetdist = (dx*dx+dy*dy)^.5
        
        local enemy_dirx, enemy_diry = math.cos(other.dir), math.sin(other.dir)
        do
          local speed_fac = 1 / constant.PROJECTILE_SPEED 
          local dx,dy = dx + enemy_dirx * targetdist * other.movespeed * speed_fac, dy + enemy_diry * targetdist * other.movespeed * speed_fac
          local dist = (dx*dx+dy*dy)^.5
          drawline(x,y,x+dx,y+dy,255,255,255)
          drawcircle(other.x,other.y,5,255,255,255)
          dx,dy = dx / dist, dy / dist
          local bx,by = math.cos(bearing),math.sin(bearing)
          local dot = dx * by - dy * bx
          set_desired_bearspeed(-dot)
          if math.abs(dot) < .01 then 
            shoot()
          end
        end        
        --drawline(x,y,other.x,other.y,255,255,0)
        pick_random_dir()
        avoid_team()
        avoid_borders()
        wait()
      --until targetdist > maxdist or other.hitpoints == 0
    end
  end
  
  avoid_borders()
  avoid_team()
  fight_closeby_enemies()
  wait()
end