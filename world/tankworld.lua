constant = {
  PROJECTILE_SPEED = 3;
  TANK_RADIUS = 8;
}

tank = {
  x = 0;
  y = 0;
  dir = 0;
  bearing = 0;
  movespeed = 0;
  turnspeed = 0;
  bearspeed = 0;
  desired_movespeed = 0;
  desired_turnspeed = 0;
  desired_bearspeed = 0;
  remaining_reloadtime = 20;
  hitpoints = 100;
  misses = 0;
  shots = 0;
  team_data_tables = {}
}

tank.__mt = {__index = tank, __tostring = function(self) return self:tostring() end}
  
function tank:create(world,ai_file,team)
  local ai,err = loadfile(ai_file)
  if not ai then
    print("====== ERROR LOADING AI FILE "..ai_file.." =======")
    print(err)
    ai = function() end
  end
  local self = setmetatable({},self.__mt)
  self.team_data_tables[team] = self.team_data_tables[team] or {}
  self.ai_file = ai_file
  self.memory = {}
  self.memory.teamdata = self.team_data_tables[team]
  self.memory.constant = {}
  for k,v in pairs(constant) do self.memory.constant[k] = v end
  function self.memory.wait() coroutine.yield() end
  function self.memory.set_desired_movespeed(speed)
    if type(speed)~= "number" then error("expected number",1) end
    self.desired_movespeed = speed
  end
  function self.memory.set_desired_turnspeed(speed)
    if type(speed)~= "number" then error("expected number",1) end
    self.desired_turnspeed = speed
  end
  function self.memory.set_desired_bearspeed(speed)
    if type(speed)~= "number" then error("expected number",1) end
    self.desired_bearspeed = speed
  end
  function self.memory.drawrect(x,y,w,h,r,g,b)
    if not self.world:may_tank_draw(self) then return end
    love.graphics.setColor(r,g,b,255)
    love.graphics.rectangle("fill",x,y,w,h)
  end
  function self.memory.drawcircle(x,y,rad,r,g,b)
    if not self.world:may_tank_draw(self) then return end
    love.graphics.setColor(r,g,b,255)
    love.graphics.circle("line",x,y,rad)
  end
  function self.memory.drawline(x1,y1,x2,y2,r,g,b)
    if not self.world:may_tank_draw(self) then return end
    love.graphics.setColor(r,g,b,255)
    love.graphics.line(x1,y1,x2,y2)
  end
  self.memory.pairs,self.memory.ipairs = pairs,ipairs
  self.memory.setmetatable = setmetatable
  self.memory.unpack = unpack
  local function copy(tab)
    local cp = {}
    for k,v in pairs(tab) do cp[k] = v end
    return cp
  end
  
  self.memory.table = copy(table)
  self.memory.string = copy(string)
  function self.memory.shoot() self:shoot() end
  self.memory.print = print
  self.memory.math = copy(math)
  
  setfenv(ai, self.memory)
  self.state = coroutine.create(ai)
  self.world = world
  self.team = team
  self.hits = {}
  self.requester_infodata = setmetatable({},{__mode = "k" })
  self.memory.self = self:get_tankinfo(self)
  self.memory.self.memory = self.memory
  return self
end

function tank:hit_test(x,y)
  local dx,dy = self.x - x, self.y -y
  local sqd = dx*dx+dy*dy
  if sqd > constant.TANK_RADIUS*constant.TANK_RADIUS then return false end
  return true
end

function tank:shoot()
  if self.remaining_reloadtime > 0 then return false end
  self.remaining_reloadtime = 20
  self.world:spawn_projectile(self,self.x,self.y,math.cos(self.bearing),math.sin(self.bearing))
  self.shots = self.shots + 1
  return true
end

function tank:set_xy(x,y)
  self.x, self.y = x,y
  return self
end

function tank:set_dir(dir)
  self.dir = dir
  return self
end

function tank:set_bearing(dir)
  self.bearing = dir
  return self
end

function tank:update_position()
  local MAX_TURNSPEED = .04
  local MAX_BEARSPEED = .08
  local speed_diff = math.max(-1,math.min(1,self.desired_movespeed)) - self.movespeed
  local turn_diff = math.max(-MAX_TURNSPEED,math.min(MAX_TURNSPEED,self.desired_turnspeed)) - self.turnspeed
  local bear_diff = math.max(-MAX_BEARSPEED,math.min(MAX_BEARSPEED,self.desired_bearspeed)) - self.bearspeed
  self.movespeed = self.movespeed + speed_diff * .2
  self.turnspeed = self.turnspeed + turn_diff * .2
  self.bearspeed = self.bearspeed + bear_diff * .2
  self.dir = self.turnspeed + self.dir
  self.bearing = self.bearing + self.bearspeed
  local dx, dy = math.cos(self.dir), math.sin(self.dir)
  self.x, self.y = self.x + dx * self.movespeed, self.y + dy * self.movespeed
  self.x = math.min(love.graphics.getWidth(),math.max(0,self.x))
  self.y = math.min(love.graphics.getHeight(),math.max(0,self.y))
  self.remaining_reloadtime = math.max(0,self.remaining_reloadtime - .1)
end

function tank:draw()
  
  love.graphics.push()
  love.graphics.translate(self.x,self.y)
  local r,g,b = HSVtoRGB(self.team,1,1)
  
  love.graphics.rotate(self.dir)
  
  love.graphics.setColor(0,0,0,180);
  love.graphics.rectangle("fill",-5 - math.sin(-self.dir)*1,-3+math.cos(-self.dir)*1,11,7)
  love.graphics.setColor(r,g,b,255);
  love.graphics.rectangle("fill",-5,-3,11,7)
  
  love.graphics.rotate(self.bearing - self.dir)
  local r,g,b = HSVtoRGB(self.team,1,.4)
  love.graphics.setColor(r,g,b,255);
  love.graphics.rectangle("fill",-.5,-1,6,1)
  love.graphics.rectangle("fill",-1.5,-1.5,3,3)
  love.graphics.pop()
  
end

function tank:get_tankinfo(requester)
  local info = self.requester_infodata[requester]
  if not info then
    info = {team = self.team}
    self.requester_infodata[requester] = info
  end
  
  info.x,info.y = self.x, self.y
  info.dir = self.dir
  info.bearing = self.bearing
  info.movespeed = self.movespeed
  info.hitpoints = self.hitpoints
  return info
end

function tank:is_alive()
  return self.hitpoints > 0
end

function tank:take_damage(dmg)
  self.hitpoints = math.max(0,self.hitpoints - dmg)
  for k,info in pairs(self.requester_infodata) do info.hitpoints = self.hitpoints end
  --print("new hitpoints: ",self.hitpoints)
end


function tank:tick()
  if coroutine.status(self.state) == "dead" then return end
  local othertanks = {}
  for i=1,#self.world.tanks do
    local other = self.world.tanks[i]
    if other ~= self then
      othertanks[#othertanks+1] = other:get_tankinfo(self)
    end
  end
  
  self.memory.bearing = self.bearing
  self.memory.dir = self.dir
  self.memory.team = self.team
  self.memory.movespeed = self.movespeed
  self.memory.turnspeed = self.turnspeed
  self.memory.bearspeed = self.bearspeed
  self.memory.MAP_WIDTH = love.graphics.getWidth()
  self.memory.MAP_HEIGHT = love.graphics.getHeight()
  self.memory.remaining_reloadtime = self.remaining_reloadtime
  self.memory.x,self.memory.y = self.x,self.y
  self.memory.othertanks = othertanks
  debug.sethook(self.state, function() error("CPU overheat",2) end, "", 50000)
  local suc,err = coroutine.resume(self.state)
  if not suc then 
    print("======== TANK CPU EXECUTION ERROR ========")
    print(debug.traceback(self.state,err))
  end
end

world = {steps = 1}
world.__mt = {__index = world}
function world:create()
  local self = setmetatable({},self.__mt)
  self.tanks = {}
  self.teams = {}
  self.projectiles = {}
  self.canvas_draw_queue = {}
  self.explosions = {}
  return self
end

function world:spawn_projectile(owner,x,y,dx,dy)
  local PROJECTILE_SPEED = constant.PROJECTILE_SPEED
  self.projectiles[#self.projectiles+1] = {x=x,y=y,vx=dx*PROJECTILE_SPEED,vy=dy*PROJECTILE_SPEED,age=0,owner=owner}
end

function world:add_tank(tank)
  self.tanks[#self.tanks+1] = tank
  self.teams[tank.team] = self.teams[tank.team] or {}
  self.teams[tank.team][#self.teams[tank.team]+1] = tank
  return self
end

function world:change_steps(delta)
  self.steps = math.min(20,math.max(1,self.steps+delta))
end

function world:queue_canvas_draw(func)
  self.canvas_draw_queue[#self.canvas_draw_queue+1] = func
end

function world:draw_exploded_tank(x,y)
  self:queue_canvas_draw(function()
    love.graphics.setColor(0,0,0,60)
    for i=1,10 do
      love.graphics.circle("fill",x,y,i)
    end
    for i=1,math.random(10)+10 do
      local dx = (math.random()*2-1)*16
      local dy = (math.random()*2-1)*16
      love.graphics.triangle("fill",
        x-dy*.25, y+dx*.25,
        x+dy*.25, y-dx*.25,
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
            p.owner.hits[t.team] = (p.owner.hits[t.team] or 0) + 1
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
      for team,hits in pairs(members[i].hits) do
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

