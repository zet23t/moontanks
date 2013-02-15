--- Basic tank class with default values as defined here.
-- A tank is defined by its position and rotation of the
-- chassis and turret and its hitpoints and its AI state.
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
  -- One table per team entries done here:
  team_data_tables = {}
}

-- The default metatable for all tank objects.
tank.__mt = {__index = tank, __tostring = function(self) return self:tostring() end}
  
--- Creates a new tank within the given world (must add it to the world later on).
-- @param world     The world that the tank will be spawned into.
-- @param ai_file   File string reference to load the AI from. If the
--                  file contains an error, an empty AI will be spawned 
--                  and the error is printed on the console.
-- @param team      The team that the tank belongs to. Should be a number between 0 to 1.
function tank:create(world,ai_file,team)
  local ai,err = loadfile(ai_file)
  if not ai then
    print("====== ERROR LOADING AI FILE "..ai_file.." =======")
    print(err)
    ai = function() end
  end
  -- create the tank object
  local self = setmetatable({},self.__mt)
  -- create a team data table if necessary
  self.team_data_tables[team] = self.team_data_tables[team] or {}
  self.ai_file = ai_file
  self.world = world
  self.team = team
  -- A table in which we store the hits we've made per team.
  self.hit_count_on_team = {}
  -- Each tank provides a tankinfo table to any other tank. 
  -- This tankinfo table may be modified by the AI so we must
  -- copy values into it and it must be a table per tank. 
  -- Moreover, to ease using the tankinfo for a longer time 
  -- inside the AI code and still updating the values in these
  -- tankinfo tables, we allocate a table per tank once and 
  -- reuse it. To allow garbage collection, we tell the GC to
  -- ignore the keys (=tanks).
  self.requester_infodata = setmetatable({},{__mode = "k" })
  
  -- Create an individual AI memory for this tank.
  self:create_ai_memory()
  -- Use the memory as environment table for the ai function.
  -- From that point on, the AI code won't be able to access
  -- anything else outside the memory.
  setfenv(ai, self.memory)
  -- The state is the actual coroutine that is used for the 
  -- AI simulation. It keeps the entire stack state of the 
  -- run program.
  self.state = coroutine.create(ai)
  return self
end

--- Set up the tank's AI memory once with "static" data.
-- If the AI changes the memory, it must deal with it.
function tank:create_ai_memory()
  -- The memory is the table for all global values of the AI. 
  -- AI scripts can use everything they find in the memory table.
  -- Anything is allowed here so we should avoid putting important
  -- stuff into the memory of the AIs. AIs are evil, you know...
  self.memory = {}
  -- We initialize every memory value individually per tank to avoid
  -- sideeffects of changes.
  
  -- Providing a wait function that allows the AI to "sleep" until 
  -- the next turn begins.
  function self.memory.wait() coroutine.yield() end
  
  -- Initial functions, kept for workshop to show how to approach 
  -- DRY principles in Lua.
  --[[
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
  end]]
  
  -- Avoiding repetition sample here:
  -- Bind function binds setters for numerical values to object values.
  -- The key is the object's value's name.
  local function bind(key)
    self.memory["set_"..key] = function (speed)
      if type(speed)~= "number" then error("expected number for "..key,1) end
      self[key] = speed
    end
    -- Returning the function allows us to chain multiple calls.
    return bind
  end
  -- Bind all our desired variables to the memory.
  bind "desired_movespeed" "desired_turnspeed" "desired_bearspeed"
  
  -- Allow the AI to do the shooting (who would have guessed!)
  function self.memory.shoot() return self:shoot() end
  
  ---
  -- Drawing functions for debugging.
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
  function self.memory.dofile(filename)
    local fn = assert(loadfile(filename))
    setfenv(fn,self.memory)
    return fn()
  end
  
  -- What follows are some globals in the memory table.
  self.memory.pairs,self.memory.ipairs = pairs,ipairs
  self.memory.setmetatable = setmetatable
  self.memory.unpack = unpack
  self.memory.print = print
  self.memory.teamdata = self.team_data_tables[self.team]
  self.memory.constant = copy(constant)
  self.memory.copy = copy
  self.memory.table = copy(table)
  self.memory.string = copy(string)
  self.memory.math = copy(math)
  -- The self reference allows the tank to get its values in a 
  -- similar way as other tankinfo data (that is provided somewhere else).
  self.memory.self = self:get_tankinfo(self)
  
  -- Finally, let's assume that intelligent beings wants to be able 
  -- to reflect on itself (like iterating over all memory values for
  -- debugging reason).
  self.memory.self.memory = self.memory
end

--- Checks if a point is hitting the tank.
-- @param x the x coordinate
-- @param y the y coordinate
-- @return true if it hits
function tank:hit_test(x,y)
  local dx,dy = self.x - x, self.y -y
  local sqd = dx*dx+dy*dy
  if sqd > constant.TANK_RADIUS*constant.TANK_RADIUS then return false end
  return true
end

--- Attempts to shoot if our reload time allows it.
function tank:shoot()
  if self.remaining_reloadtime > 0 then return false end
  self.remaining_reloadtime = 20
  self.world:spawn_projectile(self,self.x,self.y,math.cos(self.bearing),math.sin(self.bearing))
  self.shots = self.shots + 1
  return true
end

--- Simple chainable setter for the tank's position.
function tank:set_xy(x,y)
  self.x, self.y = x,y
  return self
end

--- Simple chainable setter for the tank's direction.
function tank:set_dir(radians)
  self.dir = radians
  return self
end

--- Simple chainable setter for the tank's turret's bearing.
function tank:set_bearing(radians)
  self.bearing = radians
  return self
end

--- Each simulation tick, we call this function to update the coordinates of this tank.
function tank:update_position()
  local MAX_TURNSPEED = constant.MAX_TURNSPEED
  local MAX_BEARSPEED = constant.MAX_BEARSPEED
  -- Calculate the differences to each controlable variable
  local speed_diff = math.max(-1,math.min(1,self.desired_movespeed)) - self.movespeed
  local turn_diff = math.max(-MAX_TURNSPEED,math.min(MAX_TURNSPEED,self.desired_turnspeed)) - self.turnspeed
  local bear_diff = math.max(-MAX_BEARSPEED,math.min(MAX_BEARSPEED,self.desired_bearspeed)) - self.bearspeed
  -- Now change the speed with some drag that we magically specify here.
  self.movespeed = self.movespeed + speed_diff * .2
  self.turnspeed = self.turnspeed + turn_diff * .2
  self.bearspeed = self.bearspeed + bear_diff * .2
  -- Update the values of rotation ...
  self.dir = self.turnspeed + self.dir
  self.bearing = self.bearing + self.bearspeed
  -- Calculate current velocity and add it to the position (which is a bit weird, yeah).
  local dx, dy = math.cos(self.dir), math.sin(self.dir)
  self.x, self.y = self.x + dx * self.movespeed, self.y + dy * self.movespeed
  -- Constraint the movement in the world its edges.
  self.x = math.min(constant.MAP_WIDTH,math.max(0,self.x))
  self.y = math.min(constant.MAP_HEIGHT,math.max(0,self.y))
  -- Update the reload time of our gun. We are pretty deterministic here...
  self.remaining_reloadtime = math.max(0,self.remaining_reloadtime - .1)
end

--- Drawing functions to make the tank appear in Löve2D.
function tank:draw()
  -- First, store the current matrix.
  love.graphics.push()
  love.graphics.translate(self.x,self.y)
  love.graphics.rotate(self.dir)
  
  
  -- Draw the shadow of the tank first. 
  love.graphics.setColor(0,0,0,180);
  -- The sin/cos calls are for offsetting the tank downwards.
  love.graphics.rectangle("fill",-5 - math.sin(-self.dir)*1,-3+math.cos(-self.dir)*1,11,7)
  -- Now draw the tank with our team color.
  local r,g,b = HSVtoRGB(self.team,1,1)
  love.graphics.setColor(r,g,b,255);
  love.graphics.rectangle("fill",-5,-3,11,7)
  
  -- Drawing now the turret and barrel.
  love.graphics.rotate(self.bearing - self.dir)
  local r,g,b = HSVtoRGB(self.team,1,.4)
  love.graphics.setColor(r,g,b,255);
  love.graphics.rectangle("fill",-.5,-1,6,1)
  love.graphics.rectangle("fill",-1.5,-1.5,3,3)
  
  -- Restore the original matrix now.
  love.graphics.pop()
end

--- Returns a table with information on this tank for the given requester.
-- @param   requester The tank that wants to know this. 
-- @return  A table that contains x,y,dir,bearing,movespeed and hitpoints.
--          Once this method was called for one requester, we'll continue 
--          to return the *same* info table, just with updated values.
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

--- Returns true if the tank is still allive
function tank:is_alive()
  return self.hitpoints > 0
end

--- Makes a tank taking damage updates hitpoints in all the tankinfo tables
-- that we produced in :get_tankinfo. This is necessary when the hitpoints
-- become 0 because from then on, :get_tankinfo won't be called anymore.
function tank:take_damage(dmg)
  self.hitpoints = math.max(0,self.hitpoints - dmg)
  if self.hitpoints == 0 then
    for k,info in pairs(self.requester_infodata) do info.hitpoints = self.hitpoints end
  end
end

--- Called once per simulation tick. Attempts to continue the AI execution. 
-- If the AI execution fails, an error is printed on the console and the AI 
-- gets disabled. The speed / turning won't get updated though (so it will
-- run into a wall).
function tank:tick()
  if coroutine.status(self.state) == "dead" then return end
  -- Compile a list of all other tanks on the field with all information we have.
  local othertanks = {}
  for i=1,#self.world.tanks do
    local other = self.world.tanks[i]
    if other ~= self then
      othertanks[#othertanks+1] = other:get_tankinfo(self)
    end
  end
  -- Update the memory values that are expected to be updated.
  self.memory.bearing = self.bearing
  self.memory.dir = self.dir
  self.memory.team = self.team
  self.memory.movespeed = self.movespeed
  self.memory.turnspeed = self.turnspeed
  self.memory.bearspeed = self.bearspeed
  self.memory.remaining_reloadtime = self.remaining_reloadtime
  self.memory.x,self.memory.y = self.x,self.y
  self.memory.othertanks = othertanks
  -- This is a bit outdated due to the constant table. My current AIs are 
  -- still using this, so let's keep it for now.
  self.memory.MAP_WIDTH = love.graphics.getWidth()
  self.memory.MAP_HEIGHT = love.graphics.getHeight()
  -- If the AI is doing too much in one frame disable it. The error 
  -- will be triggered after so many intructions of the VM and then the 
  -- stack traceback will be dumped. This way each AI has the very same
  -- computational resources. Interestingly, Lua is the only language that
  -- allows this to my knowledge. At least so easily.
  -- NOTE: Luajit disables certain debug abilities thus this might not
  -- work properly if in jitted mode.
  debug.sethook(self.state, function() error("CPU overheat",2) end, "", 50000)
  -- Resume the execution and track eventual errors.
  local suc,err = coroutine.resume(self.state)
  if not suc then 
    print("======== TANK CPU EXECUTION ERROR ========")
    print(debug.traceback(self.state,err))
  end
end
