# El Arma Definitiva (map 476). The palace's four rows of three tiles warp back with nothing said, but for right,
# centre, left and right; the tile of its item room only goes back. The asylum: a wall of statues falls to each of 789
# (around the south-east tile), 790 (east of the central corridor) and 791 (around its north alcove), flipped by
# strips of floor with nothing said: x 49 clears 790 and x 52 sets it, so crossing the south corridor eastwards leaves
# it on, unless along its top row, where the x 52 strip stops short; the east tile (76,18) sets 791 and clears 790,
# landing in the alcove; the alcove's south strip sets 789, x 63 of the central corridor clears it, and (66,32) clears
# 791. The alcove's tile (58,20) clears 791 and 789 and the south-east tile (73,39) 791, each while it plays its scene
# on its own tile: a change of phase there is no news. With 789 on and 791 off, as on coming back from map 474 to
# (72,39) or after (66,32), the south-east tile stands open from anywhere that keeps off x 63.
PokeAccess::Game.define("pokemon_z") do
  asylum = at(37, 80, 16, 44)
  asylum_scene = lambda { [[76, 18], [58, 20], [73, 39]].include?([$game_player.x, $game_player.y]) }
  asylum_east = lambda do
    me = $game_player
    wall = me.y >= 23 && me.y <= 26 ? [68, 67, 68, 69][me.y - 23] : 69
    me.y >= 16 && me.y <= 27 && me.x > wall
  end
  mechanic(:state, 476) do
    obstacle(/\AestatuasHypno\z/, :label => :z_tower_statue)
    [[at(0, 30, 36, 46), 2, :z_ultimate_right], [at(0, 30, 29, 31), 4, :z_ultimate_center],
     [at(0, 30, 20, 22), 6, :z_ultimate_left], [at(0, 30, 0, 13), 8, :z_ultimate_right],
     [at(36, 41, 6, 10), 11, :z_ultimate_back]].each do |zone, event, key|
      phase zone, :hint => key, :hidden => right_way(event)
    end
    phase asylum_scene, :quiet => true
    phase lambda { asylum.call && !$game_switches[791] && $game_switches[789] }, :hint => :z_asylum_out,
          :hidden => right_way(20)
    phase lambda { !$game_switches[791] && asylum_east.call }, :hint => :z_asylum_east, :hidden => right_way(18)
    phase lambda { asylum.call && !$game_switches[791] && !$game_switches[790] }, :hint => :z_asylum_1
    phase lambda { asylum.call && !$game_switches[791] }, :hint => :z_asylum_2, :hidden => right_way(18)
    phase lambda { asylum.call && !$game_switches[789] }, :hint => :z_asylum_3
    phase asylum, :hint => :z_asylum_4, :hidden => right_way(20)
  end

  # El Arma Definitiva, left vine, the library of map 472: two books hidden in its shelves (events 10 and 11, shown by the
  # lens but there to push without it) set 787 and 788 with nothing said, and the two together take away the beams on the
  # way south, far from both.
  mechanic(:state, 472) do
    watch :switch => 788, :label => :z_arma_book_nw, :on => :z_arma_book_pushed, :off => :z_arma_book_still
    watch :switch => 787, :label => :z_arma_book_e, :on => :z_arma_book_pushed, :off => :z_arma_book_still
    controls
    obstacle(/\ArayosBarrera\z/, :label => :z_arma_beams)
    solved(nil, :quiet => true) { $game_switches[787] && $game_switches[788] }
    hint :z_arma_books_hint
  end

  # Left vine, map 473: seven parts joined by bands of floor with no graphic and four mirrors with no reflection (events
  # 38 and 64 to the grey half, from x 47, and 39 and 65 back), which warp with nothing said. Each part has one way on to
  # the lift tile (event 3); the part of the band at (22,32) only goes back.
  mirror_lands = { [56, 6, 473] => :z_lanto_alt, [71, 43, 473] => :z_lanto_alt,
                   [7, 6, 473] => :z_arma_real, [22, 43, 473] => :z_arma_real }
  PokeAccess::Locator.teleport_cause(:z_arma_mirror) do |_from, to|
    mirror_lands[to] ? PokeAccess::I18n.t(mirror_lands[to]) : nil
  end
  mechanic(:state, 473) do
    arrival_hint lambda { $game_player.x >= 47 ? :z_lanto_alt : nil }
    [[38, :z_lanto_mirror_alt], [64, :z_lanto_mirror_alt], [39, :z_lanto_mirror_real],
     [65, :z_lanto_mirror_real]].each { |id, key| spot :event => id, :label => key }
    [[at(15, 24, 0, 10), 4, :z_arma_side], [at(0, 46, 0, 16), 38, :z_arma_mirror_nw],
     [at(47, 91, 0, 16), 5, :z_arma_band_n], [at(47, 91, 17, 38), 9, :z_arma_band_se],
     [at(47, 91, 39, 54), 65, :z_arma_mirror_w], [at(0, 46, 39, 54), 10, :z_arma_band_ne],
     [at(0, 46, 17, 38), 3, :z_arma_lift]].each do |zone, event, key|
      phase zone, :hint => key, :hidden => right_way(event)
    end
  end

  # Third vine, map 477: its cobwebs and doors warp with no graphic or text, and ledges make its parts one way. From the
  # top the cobweb of the north-east (event 6) goes on to map 470; from the lower parts, the door (29,57) leads back to it,
  # and from the part of the lift tile, the door (44,59) to those; the part map 470 returns to has the last cobweb (event
  # 7). Map 470's floor pushes the player along its arrows, seven times at least on the way to its one exit, the cobweb
  # (event 1): the route knows them, so that exit is all it lists.
  mechanic(:state, 477) do
    [[at(24, 40, 0, 12), 6, :z_arma_web_s], [at(0, 25, 0, 28), 6, :z_arma_web_e],
     [at(53, 61, 24, 28), 6, :z_arma_web_w], [at(26, 52, 12, 28), 6, :z_arma_web_here],
     [at(13, 15, 49, 53), 12, :z_arma_door_south], [at(20, 24, 63, 70), 12, :z_arma_door_ledge],
     [at(2, 26, 39, 43), 12, :z_arma_door_ledge], [at(2, 16, 44, 62), 12, :z_arma_door_ledge],
     [at(17, 30, 44, 66), 12, :z_arma_door_here], [at(43, 58, 39, 48), 7, :z_arma_web_flower],
     [at(46, 58, 49, 58), 7, :z_arma_web_flower], [at(45, 45, 49, 52), 7, :z_arma_web_flower],
     [at(35, 45, 46, 64), 11, :z_arma_door_ne]].each do |zone, event, key|
      phase zone, :hint => key, :hidden => right_way(event)
    end
  end
  mechanic(:state, 470) do
    arrival_hint :z_arma_push_rule
    phase lambda { true }, :hint => :z_arma_push_hint, :hidden => right_way(1)
  end
end
