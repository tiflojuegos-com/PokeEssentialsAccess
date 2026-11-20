# Mahogany Gym (map 647): an ice rink with a puck (event 2) that slides away from the player when used, up to 20 tiles,
# and a player who slides on the ice too. A parallel event sets switch 384 once the puck reaches column 27 or beyond, which
# opens the goal posts (events 11 to 13, column 28) to Pryce, and hands a puck stopped under the referee (event 20, 14,8)
# back to the start (14,20), under switch 1121. The panel at the entrance (event 1, 14,24) puts it back there too.
# The goalie (event 15, 25,14) stands still, so a puck slid up column 25 stops on the goal's top row, and from there one
# hit east scores. The assist gives the next hit from where the puck lies, as simulated on the rink: the first one needs
# the skater of row 12 (event 6) in the puck's column, the rest are fixed.
PokeAccess::Game.define("infinitefusion") do
  above_start = lambda { $game_player.x == 14 && $game_player.y < 20 }
  next_hit = lambda do
    puck = $game_map.events[2]
    return nil unless puck
    x = puck.x
    y = puck.y
    if y >= 15 && y <= 17 && x < 27 then :if_jo_mahogany_goal_hit
    elsif x == 25 && y > 17 then :if_jo_mahogany_goalie_hit
    elsif x == 14 && y == 23 then :if_jo_mahogany_wall_hit
    elsif x == 14 && y == 20 then above_start.call ? :if_jo_mahogany_down_hit : :if_jo_mahogany_first_hit
    elsif x == 14 && y > 9 && y < 20 then :if_jo_mahogany_again_hit
    else :if_jo_mahogany_reset
    end
  end

  mechanic(:state, 647) do
    auto
    name 1, :if_jo_puck_panel
    name 2, :if_jo_puck, :when => false
    name 11, :if_jo_goal_post
    name 15, :if_jo_goalie
    name 20, :if_jo_referee
    watch :switch => 1121, :say => :if_jo_referee_back
    arrival_hint :if_jo_mahogany_rule
    phase lambda { !$game_switches[384] }, :quiet => true, :hint => next_hit,
          :track => { :event => 2, :label => :if_jo_puck, :goal => [27, 15, 27, 17], :goal_label => :if_jo_goal_post }
    solved(:if_jo_goal_scored) { $game_switches[384] }
  end
end
