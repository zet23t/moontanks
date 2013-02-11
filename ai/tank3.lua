if not teamdata.team then 
  print "team table created"
  teamdata.team = {} 
  teamdata.teamsize = 0
end
teamdata.teamsize = teamdata.teamsize + 1
teamdata.team[self] = self
id = teamdata.teamsize

local move_to_x,move_to_y
local movepoints = {
  {50,50};
  {MAP_WIDTH-50,50};
  {MAP_WIDTH-50,MAP_HEIGHT-50};
  {50,MAP_HEIGHT-50};
}
local movepointidx = 1
while true do
  local function dist(x1,y1,x2,y2)
    local dx,dy = x1-x2,y1-y2
    return (dx*dx+dy*dy)^.5
  end
  
  local target
  local function group_center()
    local x,y,n = x,y,1
    for i=1,#teamdata.team do 
      local tank
      if othertanks[i].team == team then 
        x,y,n = x + othertanks[i].x, y + othertanks[i].y, n +1 
      end
    end
    
    return x / n, y / n
  end
  
  local function pt_line_dist (px,py,x1,y1,x2,y2)
    local dx,dy = x2-x1,y2-y1
    local dist = (dx*dx+dy*dy)^.5
    return ((px - x1) * (y2 - y1) - (py - y1) * (x2 - x1)) / dist
  end
  
  local function set_target()
    local gx,gy = group_center()
    
    if target and target.hitpoints > 0 and dist(target.x,target.y,gx,gy) < 300 then
      
    end
  end
  
  local function driveto(tx,ty,speed)
    local dx,dy = tx-x,ty-y
    local sqdist = dx*dx+dy*dy
    if sqdist > 0 then
      local dist = sqdist^.5
      local dir_x,dir_y = math.cos(dir),math.sin(dir)
      dx,dy = dx / dist, dy / dist
      set_desired_turnspeed(-dx*dir_y+dy*dir_x)
      set_desired_movespeed(math.min(math.max(0,dist*.1-.1),1)*(speed or 1))
      return dist
    end
    return 0
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
  
    
  local function formation_drive()
    local formation = {}
    for tank in pairs(teamdata.team) do
      if tank.hitpoints > 0 then formation[#formation+1]= tank end
    end
      
    table.sort(formation,function(a,b) return a.memory.id < b.memory.id end)
    local function index_of(id)
      for i=1,#formation do 
        if formation[i].memory.id == id then return i end 
      end
      return x,y
    end
    
    if formation[1] == self then
      drawcircle(x,y,15,255,0,0)
      local dx,dy = math.cos(dir),math.sin(dir)
      drawline(x,y,x-dx*150,y-dy*150,255,0,0)
      
      
      
      function teamdata.my_formation_pos(id)
        local idx = index_of(id) - 1
        return x-dx*idx*30,y-dy*idx*30
      end
      
      local shootat
      local left_cnt,right_cnt = 0,0
      local right_closest,left_closest,left_dist,right_dist
      for i=1,#othertanks do
        local tank = othertanks[i]
        local dist = dist(x,y,tank.x,tank.y)
        if tank.team~=team and dist < 300 and dist > 50 then
          local linedist = pt_line_dist(tank.x,tank.y,x,y,x+dx,y+dy)
          if math.abs(linedist) > 50 then 
            shootat = tank
          
            if linedist < 0 then 
              left_cnt = left_cnt + 1 
              linedist = -linedist
              if not left_closest or left_dist < dist then
                left_closest,left_dist = tank,dist
              end
            else 
              right_cnt = right_cnt + 1 
              if not right_closest or right_dist < dist then
                right_closest,right_dist = tank,dist
              end
            end
          end
        end
      end
      if left_cnt > right_cnt then 
        shootat = left_closest
      else
        shootat = right_closest
      end
      
      if shootat then
        drawcircle(shootat.x,shootat.y,40,255,255,0)
      end
      
      
      
      function teamdata.my_target(id)
        if shootat then 
          local speed_fac = 1 / constant.PROJECTILE_SPEED 
          local enemy_dirx, enemy_diry = math.cos(shootat.dir),math.sin(shootat.dir)
          local targetdist = dist(shootat.x,shootat.y,x,y)
          local movespeed = shootat.movespeed
          local x,y = shootat.x + enemy_dirx * targetdist * movespeed * speed_fac, 
            shootat.y + enemy_diry * targetdist * movespeed * speed_fac
          return x+(math.random()-.5)*20,y+(math.random()-.5)*20
        end
      end
      
      local restdist
     if move_to_x then
        restdist = driveto(move_to_x,move_to_y,.75)
        --print(move_to_x,move_to_y,restdist)
        
      end
      if (not move_to_x) or (restdist < 40) then
        local attempts = 0
        repeat
          move_to_x = math.random()*700+50
          move_to_y = math.random()*500+50
          local dx,dy = x-move_to_x,y-move_to_y
          local avg_enemy_dist,enemy_cnt = 0,0
          for i=1,#othertanks do
            local t = othertanks[i]
            if t.team~=team then
              local dist = dist(x,y,t.x,t.y)
              avg_enemy_dist = avg_enemy_dist + dist
              enemy_cnt = enemy_cnt + 1
            end
          end
          if enemy_cnt == 0 then break end
          avg_enemy_dist = avg_enemy_dist / enemy_cnt
          attempts = attempts +1
        until dx*dx+dy*dy > 200*200 and avg_enemy_dist > 500/attempts or attempts > 15
          
          
              
        
       --[[ local closest_dist, closest_idx
        for i=1,#movepoints do 
          local dist = dist(x,y,unpack(movepoints[i]))
          if dist > 50 then
            if not closest_dist or (dist < closest_dist) then 
              closest_dist, closest_idx = dist, i 
            end
          end
        end
        
        move_to_x,move_to_y = unpack(movepoints[closest_idx])
        --movepointidx = (movepointidx % #movepoints) + 1]]
      end
      
    elseif teamdata.my_formation_pos then
      local target_x,target_y = teamdata.my_formation_pos(id)
      drawline(x,y,target_x,target_y,0,255,0)
      driveto(target_x,target_y)
    end
    local sx,sy = teamdata.my_target(id)
    if sx then
      aim_and_shoot_at(sx,sy)
    end
    
  end
  
  formation_drive()
  wait()
end