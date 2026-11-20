# Yukino's Ice Slider Challenge (Yuki Temple B1F, map 275) and Masao's Fire Juggler Challenge (Netsu Temple B1F, map 273),
# optional: with three failures a pupil is fought instead and only the prize is lost. Yuki: four pressure plates over the ice
# courses (events 13 to 16 for the first, 28 to 31 for the second), var 150 counting them; then a final challenge, started by
# event 33 (self switch A) and ended by it (B), on ice with six boulders (events 36 to 41), two stones that close the middle
# (34 on (37, 39) and 35 on (37, 49), broken by what boulders 36 and 37 do on (29, 39) and (45, 39) and boulder 41 on (46, 49)),
# sixteen deflectors, whose arrow is the map's tile under them, that push the player one tile the way it points (event 47 turns
# round once its self switch A is on, and 46 and 50 each turn round once their self switch B is, while A switches them off), and the switch of event 76 on
# (37, 56). A boulder that stops on a sensor tile slides off by itself and stays fixed, and the deflector there is switched
# off. Netsu: boulders pushed onto sensors that read where they lie.
PokeAccess::Game.define("keishou") do
  plates = (13..16).to_a + (28..31).to_a
  deflectors = [42, 43, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 77]
  final_running = lambda { $game_self_switches[[275, 33, "A"]] && !$game_self_switches[[275, 33, "B"]] }
  arrows = { 42 => :left, 43 => :up, 46 => :right, 47 => :right, 48 => :left, 49 => :left, 50 => :left, 51 => :left, 52 => :left,
             53 => :left, 54 => :up, 55 => :up, 56 => :up, 57 => :up, 58 => :right, 77 => :right }
  flipped = lambda do |id|
    switched = $game_self_switches[[275, id, id == 47 ? "A" : "B"]]
    switched && [46, 47, 50].include?(id)
  end
  opposite = { :left => :right, :right => :left, :up => :down }
  deflector_label = lambda do |ev|
    way = arrows[ev.id]
    way = opposite[way] if flipped.call(ev.id)
    "ks_o_ice_deflector_#{way}".to_sym
  end

  mechanic(:state, 275) do
    auto
    name plates, :ks_o_pressure_plate, :when => lambda { |ev| !$game_self_switches[[275, ev.id, "A"]] }
    count :ks_o_plates_pressed, :var => 150, :of => 4, :hide_zero => true
    arrival_hint :ks_o_ice_rule, :once => true
  end

  mechanic(:state, 275, :part => :final) do
    auto
    name deflectors, lambda { |ev| deflector_label.call(ev) },
         :when => lambda { |ev| final_running.call && (ev.id == 47 || !$game_self_switches[[275, ev.id, "A"]]) }
    name 76, :ks_o_ice_switch, :when => lambda { |_ev| final_running.call && !$game_self_switches[[275, 76, "A"]] }
    watch :self => [33, "A"], :say => :ks_o_ice_final_rule
    hint :ks_o_ice_final_hint
    active { PokeAccess::Puzzles.assist? && final_running.call }
  end

  mechanic(:state, 273) do
    auto
    obstacle({ :events => [13, 14, 15, 21, 22, 23, 24, 30, 31, 32, 34] }, :moving => true, :label => :ks_o_juggled_flame)
    hint :ks_o_fire_course_hint
    active { PokeAccess::Puzzles.assist? }
    arrival_hint :ks_o_fire_course_rule, :once => true
  end
end
