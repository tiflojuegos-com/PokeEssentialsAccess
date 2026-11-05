# Bastión Fractal (map 321), the ice floor of the west wing: each of its 38 tiles (events 1 to 38) breaks with a sound
# the first time it is trodden, its self switch A, and adds to var 204; trodden again it mends them all and drops the
# player at (59,39) with another sound, and only the strip (5-8,26) clears the count. At 38 an autorun says the rock
# (7,14) has gone, so the round must end on (7,15); switch 541, north of the rock, retires the floor. Each tile is a
# phase: what lies around it as it is reached, the broken tiles as a sighted player sees them, and with the assist the
# next step of a round that can still be finished, searched from the tiles left (four ways through in all).
PokeAccess::Game.define("pokemon_z") do
  ice = [[2, 15, 1], [3, 15, 2], [2, 16, 3], [2, 17, 4], [2, 18, 5], [5, 15, 6], [6, 15, 7], [7, 15, 8], [8, 15, 9],
         [7, 16, 10], [6, 16, 11], [5, 16, 12], [4, 16, 13], [3, 16, 14], [4, 17, 15], [4, 18, 16], [3, 18, 17],
         [5, 18, 18], [5, 17, 19], [7, 17, 20], [6, 18, 21], [7, 18, 22], [8, 18, 23], [9, 17, 24], [8, 17, 25],
         [9, 18, 26], [9, 16, 27], [10, 16, 28], [10, 17, 29], [11, 17, 30], [11, 18, 31], [12, 18, 32], [12, 17, 33],
         [12, 16, 34], [9, 15, 35], [10, 15, 36], [11, 15, 37], [12, 15, 38]]
  ice_event = {}
  ice.each { |x, y, id| ice_event[[x, y]] = id }
  ice_broken = lambda { |xy| $game_self_switches[[321, ice_event[xy], "A"]] }
  ice_falling = lambda { |xy| ice_broken.call(xy) && $game_player.moving? }
  ice_sides = lambda do |key, sides|
    sides.empty? ? nil : PokeAccess::I18n.t(key, :list => PokeAccess::Routes::Text.and_list(sides))
  end
  ice_around = lambda do |xy|
    if ice_falling.call(xy)
      nil
    else
      free = []
      broken = []
      PokeAccess::Puzzles::SIDES.each do |dx, dy, key|
        side = [xy[0] + dx, xy[1] + dy]
        if ice_event[side]
          (ice_broken.call(side) ? broken : free).push(PokeAccess::I18n.t(key))
        elsif side == [7, 14] && $game_variables[204] >= 38
          free.push(PokeAccess::I18n.t(key))
        end
      end
      PokeAccess.sentences([ice_sides.call(:z_ice_free, free), ice_sides.call(:z_ice_broken, broken)])
    end
  end
  ice_step = lambda do |xy, left|
    PokeAccess::Puzzles::SIDES.find do |dx, dy, _key|
      side = [xy[0] + dx, xy[1] + dy]
      if left[side] && (side != [7, 15] || left.size == 1)
        left.delete(side)
        done = left.empty? || ice_step.call(side, left)
        left[side] = true
        done
      end
    end
  end
  ice_next = lambda do |xy|
    left = {}
    ice.each { |x, y, id| left[[x, y]] = true unless $game_self_switches[[321, id, "A"]] || [x, y] == xy }
    if ice_falling.call(xy) then nil
    elsif left.empty? then xy == [7, 15] ? :z_ice_done : :z_ice_lost
    else
      side = left[[7, 15]] ? ice_step.call(xy, left) : nil
      side ? [:z_ice_next, { :dir => PokeAccess::I18n.t(side[2]) }] : :z_ice_lost
    end
  end
  PokeAccess::Locator.teleport_cause(:z_ice_fall) do |_from, to|
    to == [59, 39, 321] ? PokeAccess::I18n.t(:z_ice_fell) : nil
  end

  # The same map's buttons, which the player treads on, sound and change the tile blocks with no graphic or text, near or
  # out of sight: events 71 (569 on), 72 (571, 570, 572, 573 on, 569 off), 87 (579, 577, 569 on) and 94 (575, 574, 576 on,
  # 579 off), each only reachable after the last, and the last opens the way to the north door (event 62). Var 209
  # reaches 10 with the bastion beaten. The room a fall lands in leaves by its door (event 41) alone.
  fractal_open = lambda { $game_variables[209] < 10 }
  mechanic(:state, 321) do
    watch :switch => 569, :label => :z_fractal_mid, :on => :z_fractal_open, :off => :z_fractal_shut
    watch :switch => 571, :label => :z_fractal_low, :on => :z_fractal_low_on, :off => :z_fractal_shut
    watch :switch => 577, :label => :z_fractal_high, :on => :z_fractal_high_on, :off => :z_fractal_shut
    watch :switch => 576, :label => :z_fractal_north, :on => :z_fractal_north_on, :off => :z_fractal_shut
    ice.each do |x, y, _id|
      phase lambda { fractal_open.call && !$game_switches[541] && $game_player.x == x && $game_player.y == y },
            :title => lambda { ice_around.call([x, y]) }, :hint => lambda { ice_next.call([x, y]) },
            :progress => { :var => 204, :of => 38, :label => :z_ice_count, :hide_zero => true }
    end
    ice_hall = at(5, 8, 19, 25)
    phase lambda { fractal_open.call && !$game_switches[541] && $game_variables[204] < 38 && ice_hall.call },
          :title => :z_ice_rule
    ice_landing = at(50, 62, 39, 48)
    phase lambda { fractal_open.call && ice_landing.call }, :quiet => true, :hint => :z_fractal_back, :hidden => right_way(41)
    [[lambda { !$game_switches[569] && !$game_switches[571] }, 71, :z_fractal_go1, [71, 72, 87, 94]],
     [lambda { !$game_switches[571] }, 72, :z_fractal_go2, [72, 87, 94]],
     [lambda { !$game_switches[577] }, 87, :z_fractal_go3, [87, 94]],
     [lambda { !$game_switches[576] }, 94, :z_fractal_go4, [94]],
     [lambda { true }, 62, :z_fractal_go5, []]].each do |live, event, key, buttons|
      phase lambda { fractal_open.call && live.call }, :hint => key, :hidden => right_way(event),
            :spots => buttons.map { |id| { :event => id, :label => :z_fractal_button } }
    end
  end
end
