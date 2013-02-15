dofile "ai/tankutil.lua"

while true do
  -- avoid the most closest tanks. We also want to avoid walls pretty equally.
  -- Thus, we search the closest tank from the list of all tanks. To avoid
  -- the walls, we add "virtual" tanks that are scaring us away from the walls.
  local virtual_list = copy(othertanks)
  virtual_list[#virtual_list+1] = {x = x, y = -5, team = team}
  virtual_list[#virtual_list+1] = {x = x, y = MAP_HEIGHT+5, team = team}
  virtual_list[#virtual_list+1] = {x = -5, y = y, team = team}
  virtual_list[#virtual_list+1] = {x = MAP_WIDTH+5, y = y, team = team}
  
  local tanks_by_dist = tanks_by_dist(x,y,virtual_list)
  local tank_avoid = tanks_by_dist[1]
  if tank_avoid then
    local dx,dy = tank_avoid.x-x,tank_avoid.y-y
    driveto(x-dx,y-dy)
  end
  
  -- we can now shoot at the closest enemy by search through the list we compiled
  for i=1,#virtual_list do 
    local opponent = tanks_by_dist[i]
    if opponent.team ~= team then
      if opponent.dist > 250 then 
        -- bravely approach the enemy 
        driveto(opponent.x,opponent.y)
        drawcircle(x,y,50,255,0,0)
        if opponent.dist > 350 then
          -- but if still too far away don't shoot
          break 
        end
      end
      aim_with_prediction_and_shoot(opponent)
      --drawline(x,y,opponent.x,opponent.y,255,0,0)
      break
    end
  end
  
  
  
  wait()
end
