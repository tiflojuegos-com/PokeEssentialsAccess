# Perfection Base. Map 641: nine boulders that are pushed by walking against them, and nine floor switches in four colours
# that a parallel event reads each frame: the number of events standing on a colour's switches, whatever they are (a boulder,
# the Manaphy statue moved there with Heart Swap), plus the player when standing on the last switch of the colour's list,
# turns switches 551 to 554 on, which removes that colour's pillars. Red asks for two of its three, green one, yellow three and
# blue two (the signs say so). Map 642: the panel (event 1) of the rotation circuit whose win calls Mewtwo.
PokeAccess::Game.define("insurgence") do
  colours = [
    { :name => :red, :switch => 551, :need => 2, :pillars => [4, 5],
      :tiles => [[35, 23], [35, 18], [42, 23]] },
    { :name => :green, :switch => 552, :need => 1, :pillars => [6, 7], :tiles => [[45, 13]] },
    { :name => :yellow, :switch => 553, :need => 3, :pillars => [9, 10],
      :tiles => [[31, 6], [32, 14], [42, 11]] },
    { :name => :blue, :switch => 554, :need => 2, :pillars => [21, 22, 23, 24], :tiles => [[36, 50], [34, 51]] }
  ]
  covered = lambda do |tiles|
    on_events = tiles.select { |t| $game_map.events.values.any? { |e| e && e.x == t[0] && e.y == t[1] } }.length
    last = tiles.last
    on_events + ($game_player.x == last[0] && $game_player.y == last[1] ? 1 : 0)
  end
  player_tile = lambda do |tile|
    PokeAccess::Puzzles.assist? ? [:ins_o1_pb_tile_player, { :tile => PokeAccess::I18n.t(tile) }] : tile
  end
  reached = {}
  [:map, :reset].each { |epoch| PokeAccess::World::Epoch.on(epoch) { reached.clear } }
  reading = lambda do |c|
    value = [covered.call(c[:tiles]), c[:need]].min
    reached[c[:name]] = true if value >= c[:need]
    value
  end
  closing = lambda do |c|
    was_open = reached[c[:name]]
    reached[c[:name]] = false
    was_open ? :ins_o1_pb_closed : ""
  end
  open_count = lambda { colours.select { |c| $game_switches[c[:switch]] }.length }
  circuit = lambda do |_ev|
    PokeAccess::Puzzles.assist? ? :ins_o1_circuit_reward : :ins_o1_circuit
  end
  mechanic(:state, 641, :part => :blocks) do
    auto
    colours.each do |c|
      name c[:pillars], "ins_o1_pb_pillar_#{c[:name]}".to_sym
      tile = "ins_o1_pb_tile_#{c[:name]}".to_sym
      c[:tiles][0...-1].each { |t| spot :at => t, :label => tile, :onto => true }
      spot :at => c[:tiles].last, :label => lambda { player_tile.call(tile) }, :onto => true
      count "ins_o1_pb_count_#{c[:name]}".to_sym, :of => c[:need],
            :reset => lambda { closing.call(c) },
            :value => lambda { reading.call(c) }
    end
    count :ins_o1_pb_open, :of => colours.length, :reset => false, :value => open_count, :assist => true
    arrival_hint :ins_o1_pb_rule, :once => true
    hint :ins_o1_pb_hint
  end
  mechanic(:state, 642, :part => :circuit) do
    auto
    name 1, circuit
  end
end
