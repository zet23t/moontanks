--- World class.
-- The world manages all the tanks and interaction and drawing.
world = {steps = 1}
world.__mt = {__index = world}

--- World constructor.
function world:create()
  local self = setmetatable({},self.__mt)
  -- A list of (only alive) tank from 1 to n.
  self.tanks = {}
  -- A map of teams where the teams are keys and values are lists of tanks.
  self.teams = {}
  -- A list of active projectiles from 1 to n.
  self.projectiles = {}
  -- A queue of debugging stuff that is supposed to be drawn.
  self.canvas_draw_queue = {}
  -- A list of active explosions that are only rendered
  self.explosions = {}
  return self
end

--- Spawns a projectile in the world.
-- @param owner Tank that has shot the projectile; only tank that is ignoring this projectile.
-- @param x X coordinate where to spawn the projectile
-- @param y Y coordinate where to spawn the projectile
-- @param dx direction velocity vector (assumed to be unit length!)
-- @param dy direction velocity vector (assumed to be unit length!)
function world:spawn_projectile(owner,x,y,dx,dy)
  local PROJECTILE_SPEED = constant.PROJECTILE_SPEED
  self.projectiles[#self.projectiles+1] = {x=x,y=y,vx=dx*PROJECTILE_SPEED,vy=dy*PROJECTILE_SPEED,age=0,owner=owner}
end

--- Adds a tank to the world.
-- @param tank Tank to be added to the list of tanks.
function world:add_tank(tank)
  self.tanks[#self.tanks+1] = tank
  self.teams[tank.team] = self.teams[tank.team] or {}
  self.teams[tank.team][#self.teams[tank.team]+1] = tank
  return self
end

--- Helper function to influence the number of simulated steps per tick.
-- @param delta Number value how much to change the number of steps.
function world:change_steps(delta)
  self.steps = math.min(20,math.max(1,self.steps+delta))
end

--- Queues stuff that is to be drawn on the canvas.
-- We need to queue it because there is a special phase in the drawing
-- steps where we want to draw on the map's canvas (where all the wheel
-- tranks are drawn). We queue the draws until it's time to draw those.
-- @param func  Function without arguments to be called when it's the right time.
--              The function can then draw on the canvas.
function world:queue_canvas_draw(func)
  self.canvas_draw_queue[#self.canvas_draw_queue+1] = func
end

--- Called when a tank explodes. Will draw a black mark on the map's canvas.
-- @param x X coordinate of the explosion.
-- @param y Y coordinate of the explosion.
function world:draw_exploded_tank(x,y)
  self:queue_canvas_draw(function()
    love.graphics.setColor(0,0,0,60)
    for i=1,10 do
      -- Repetively drawing of circles will make a circular gradient because
      -- of the blend.
      love.graphics.circle("fill",x,y,i)
    end
    for i=1,math.random(10)+10 do
      -- Draw now random triangles that resemble spikes in the explosion.
      local dx = (math.random()*2-1)*20
      local dy = (math.random()*2-1)*20
      -- With dx,dy we can create the perpendicular vector by flipping 
      -- the pair and negating one of it.
      love.graphics.triangle("fill",
        x-dy*.25, y+dx*.2,
        x+dy*.25, y-dx*.2,
        x+dx,y+dy)
    end
  end)
end

function world:draw_exploded_projectile(x,y,vx,vy)
  self:queue_canvas_draw(function()
    love.graphics.setColor(0,0,0,140)
    love.graphics.circle("fill",x,y,2)
    for i=1,math.random(4) do
      love.graphics.line(x,y,x+vx*4+(math.random()*2-1)*6,y+vy*4+(math.random()*2-1)*6)
    end
    
  end)
end
  
function world:add_explosion(x,y,size)
  self.explosions[#self.explosions+1] = {
    x = x;
    y = y;
    size = size;
    age = 0;
  }
end

function world:step()
  for i=1,self.steps do
    for i=#self.projectiles,1,-1 do
      local p = self.projectiles[i]
      p.age = p.age + 1
      if p.age > 150 then 
        table.remove(self.projectiles,i)
        p.owner.misses = p.owner.misses + 1
        self:draw_exploded_projectile(p.x,p.y,p.vx,p.vy)
        self:add_explosion(p.x+p.vx,p.y+p.vy,6)
      else 
        p.x = p.x + p.vx
        p.y = p.y + p.vy
        for j=#self.tanks,1,-1 do
          local t = self.tanks[j]
          if t~=p.owner and t:hit_test(p.x,p.y) then
            t:take_damage(15)
            if not t:is_alive() then
              table.remove(self.tanks,j)
              self:draw_exploded_tank(t.x,t.y)
              self:add_explosion(t.x,t.y,30)
            end
            table.remove(self.projectiles,i)
            p.owner.hit_count_on_team[t.team] = (p.owner.hit_count_on_team[t.team] or 0) + 1
            self:add_explosion(p.x+p.vx,p.y+p.vy,10)
          end
        end
      end
    end
    for i=1,#self.tanks do self.tanks[i]:tick() end
    for i=1,#self.tanks do self.tanks[i]:update_position() end
    local tank_rad2 = constant.TANK_RADIUS*constant.TANK_RADIUS*4
    for i=1,#self.tanks do
      local tank_a = self.tanks[i]
      for j=i+1,#self.tanks do
        local tank_b = self.tanks[j]
        local dx,dy = tank_b.x - tank_a.x, tank_b.y - tank_a.y
        local sqdist = dx*dx+dy*dy
        if sqdist < tank_rad2 and sqdist > 0 then
          local dist = sqdist ^ .5
          local ndx,ndy = dx / dist, dy / dist
          local depth = constant.TANK_RADIUS*2 - dist
          tank_a.x,tank_a.y = tank_a.x - ndx * depth, tank_a.y - ndy * depth
          tank_b.x,tank_b.y = tank_b.x + ndx * depth, tank_b.y + ndy * depth
        end
      end
    end
    for i=#self.explosions,1,-1 do
      local p = self.explosions[i]
      p.age = p.age + 1
      if p.age > p.size then
        table.remove(self.explosions,i)
      end
    end
    
  end
end

function world:may_tank_draw(tank)
  return self.draw_debug_info
end

function world:toggle_draw_debug_info()
  self.draw_debug_info = not self.draw_debug_info
end

local canvas
function world:draw()
  if not canvas then
    canvas = love.graphics.newCanvas()
    canvas:clear(0,0,0,0)
    love.graphics.setCanvas(canvas)
    love.graphics.setColor(0,0,0,255)
    --love.graphics.rectangle("fill",0,0,100,100)
  end
  love.graphics.setCanvas(canvas)
  love.graphics.setBlendMode("additive")
  for i=1,#self.tanks do
    local t = self.tanks[i]
    love.graphics.setColor(0,0,0,70)
    --love.graphics.circle("fill",t.x,t.y,2)
    local lx,ly = t.last_draw_x, t.last_draw_y
    t.last_draw_x,t.last_draw_y = t.x,t.y
    if lx then
      local dx,dy = t.x - lx, t.y - ly
      local dist = (dx*dx+dy*dy)^.5
      if dist > 0 then
        dx,dy = dx / dist * 1.5, dy / dist * 1.5
        
        love.graphics.line(t.x-dy,t.y+dx,lx-dy,ly+dx)
        love.graphics.line(t.x+dy,t.y-dx,lx+dy,ly-dx)
      end
    end
  end
  for i=1,#self.canvas_draw_queue do
    self.canvas_draw_queue[i]()
  end
  
  self.canvas_draw_queue = {}
  love.graphics.setCanvas()
  
  love.graphics.setBackgroundColor(0xCD,0xC5,0xBD)
  love.graphics.clear();
  love.graphics.setBlendMode("alpha")
  self:draw_stats()
  
  love.graphics.setBlendMode("premultiplied")
  love.graphics.setColor(255,255,255,255)
  love.graphics.draw(canvas)
  
  love.graphics.setBlendMode("alpha")
  
  for i=1,#self.tanks do self.tanks[i]:draw() end
  
  for i=1,#self.projectiles do
    local p = self.projectiles[i]
    love.graphics.setColor(0,0,0,255)
    love.graphics.line(p.x,p.y, p.x-p.vx, p.y-p.vy)
    love.graphics.setColor(0,0,0,80)
    love.graphics.line(p.x,p.y, p.x-p.vx*2, p.y-p.vy*2)
  end
  
  for i=#self.explosions,1,-1 do
    local p = self.explosions[i]
    local rad = math.min(p.size,p.age)
    love.graphics.setColor(255,255,128,255 * (1-p.age / p.size))
    love.graphics.circle("fill",p.x,p.y,p.age)
  end
  
end
  
function world:draw_stats()
  -- draw team stats
  local y = 10
  for team,members in pairs(self.teams) do
    local r,g,b = HSVtoRGB(team,.5,.7)
    love.graphics.setColor(r,g,b,255)
    love.graphics.rectangle("fill",10,y,10*#members,20)
    
    local r,g,b = HSVtoRGB(team,.5,1)
    love.graphics.setColor(r,g,b,255)
    love.graphics.print(members[1].ai_file,10,y+8)
    local hp = 0
    local teamhits = {}
    for i=1,#members do 
      for team,hits in pairs(members[i].hit_count_on_team) do
        teamhits[team] = (teamhits[team] or 0) + 1
      end
      if members[i].hitpoints > 0 then
        love.graphics.setColor(r,g,b,255)
        love.graphics.rectangle("fill",i*10,y,8,8)
        love.graphics.setColor(r*.5,g*.5,b*.5,255)
        love.graphics.rectangle("fill",i*10,y,8,8-members[i].hitpoints / 100 * 8)
      end
    end
    local x = 10 + #members * 10
    for hitteam,hits in pairs(teamhits) do
      local r,g,b = HSVtoRGB(hitteam,.5,1)
      love.graphics.setColor(r,g,b,255)
      love.graphics.rectangle("fill",x,y,hits,20)
      x = x+hits
    end
    
    y = y + 20
  end
  
  
end

