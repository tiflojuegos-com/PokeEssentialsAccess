# Chateau Lanto: mirrors without a reflection change dimension with no text (88 to 94 and back, at the same tiles),
# and the grey maps 92, 94 and 95 copy 86, 88 and 109, named alike. Each map part has one way on, to the wine (86's
# event 18, its self switch A once taken), then to the chalice (86's event 12, A once poured); map 88 falls in three
# parts its copy joins in two. On 109: the hidden button under the Gallade statue, until var 89 reaches 10; the lever
# (switch 160) that lowers the spikes on the way to the entrance, with nothing said.
PokeAccess::Game.define("pokemon_z") do
  wine_taken = lambda { $game_self_switches[[86, 18, "A"]] }
  wine_poured = lambda { $game_self_switches[[86, 12, "A"]] }
  lanto_way = lambda do |rows|
    lambda do
      row = rows.find { |zone, _wine, _chalice| zone.nil? || zone.call }
      step = PokeAccess::I18n.t(row[wine_taken.call ? 2 : 1])
      [wine_taken.call ? :z_lanto_to_chalice : :z_lanto_to_wine, { :step => step }]
    end
  end
  lanto_east = at(43, 57, 15, 25)
  lanto_north = lambda { $game_player.y <= 9 || ($game_player.x <= 14 && $game_player.y <= 25) }
  lanto_upper = at(45, 69, 0, 22)
  lanto_hall = at(0, 31, 0, 20)
  lanto_cells = at(0, 13, 30, 40)
  [[86, nil, [[lanto_east, :z_lanto_step_wine, :z_lanto_step_here],
              [lanto_north, :z_lanto_step_up_right, :z_lanto_step_up_right],
              [nil, :z_lanto_step_low_left, :z_lanto_step_chalice]]],
   [88, nil, [[at(58, 69, 0, 14), :z_lanto_step_here, :z_lanto_step_here],
              [lanto_upper, :z_lanto_step_right, :z_lanto_step_mirror_north],
              [nil, :z_lanto_step_mirror_center, :z_lanto_step_low_left]]],
   [92, :z_lanto_alt, [[lanto_east, :z_lanto_step_here, :z_lanto_step_here],
                       [lanto_north, :z_lanto_step_up_left, :z_lanto_step_up_right],
                       [nil, :z_lanto_step_low_left, :z_lanto_step_low_left]]],
   [94, :z_lanto_alt, [[lanto_upper, :z_lanto_step_mirror_north, :z_lanto_step_up_right],
                       [nil, :z_lanto_step_up_left, :z_lanto_step_mirror_center]]],
   [95, :z_lanto_alt, [[lanto_hall, :z_lanto_step_door, :z_lanto_step_door]]]].each do |map, rule, ways|
    mirrors = { 88 => [[2, 18, 19], :z_lanto_mirror_alt], 94 => [[9, 10, 11], :z_lanto_mirror_real] }[map]
    mechanic(:state, map) do
      arrival_hint rule if rule
      mirrors[0].each { |id| spot :event => id, :label => mirrors[1] } if mirrors
      phase lambda { !wine_poured.call && (map != 95 || lanto_hall.call) }, :quiet => true, :hint => lanto_way.call(ways),
            :spots => map == 86 ? [{ :event => 12, :label => :z_lanto_chalice }] : []
      phase lambda { true }, :quiet => true if rule
    end
  end
  mechanic(:state, 109) do
    watch :switch => 160, :label => :z_lanto_lever, :on => :z_lanto_lever_on, :off => :z_lanto_lever_off
    controls
    obstacle(/\Apinchos\z/, :label => :z_spikes)
    phase lambda { $game_variables[89] < 10 }, :quiet => true, :hint => :z_lanto_button_hint,
          :spots => [{ :event => 2, :label => :z_lanto_button }]
    phase lambda { !wine_poured.call && lanto_hall.call }, :quiet => true,
          :hint => lanto_way.call([[nil, :z_lanto_step_door, :z_lanto_step_door]])
    phase lambda { !$game_switches[160] && lanto_cells.call }, :quiet => true, :hint => :z_lanto_lever_hint
  end
end
