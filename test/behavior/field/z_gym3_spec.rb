# Pokemon Z's 3rd gym, "Bastion Pokemon" (maps 87 and 89). The room is walled off by electric barriers and
# opened by floor plates, and the plates carry NO graphic on the page that reacts to being stepped on --
# so nothing but the switch their commands write can find them. Declared with barriers and no watch list,
# which is how it shipped, the player heard walls all around and there was nothing to walk to: the plates
# were not emitters, not locator targets, and the info key had nothing to read.
#
# The switch numbers are the ones on the maps and differ between the two floors, which is the reason this
# pins them: one shared list of switches would be right on one floor and quietly wrong on the other.

# The reset between suites wipes the registered puzzles, so the profile file is loaded here the way the
# harness loads one: this repo's real file, by absolute path, which is what makes the switch numbers below
# the shipped ones and not a copy that can drift.
def load_z_puzzles
  path = File.join(Harness::ROOT, "games", "pokemon_z", "puzzles.rb")
  eval(File.read(path), TOPLEVEL_BINDING, path)
  PokeAccess::Puzzles.instance_variable_get(:@defs)
end

Suite.define("z 3rd gym: both floors declare their own plates, by the switch each one writes") do
  defs = load_z_puzzles
  { 87 => [142, 141, 143, 147], 89 => [144, 145, 146, 148] }.each do |map, want|
    d = defs[map]
    truthy "map #{map} is declared as a puzzle", d.is_a?(Hash)
    eq "map #{map} watches the switches its own plates write", (d[:watch] || []).map { |w| w[:switch] },
       want
    truthy "and still calls the beams walls, so they keep pinging as obstacles",
           (d[:obstacles] || []).any? { |o| ("rayosRojosV" =~ o[:match]) && o[:kind] == :wall }
  end
  eq "the floors read their switches in the same order, so the room sounds the same on both",
     defs[87][:watch].map { |w| w[:label] }, defs[89][:watch].map { |w| w[:label] }
  falsy "and neither declares a solved state: the room never settles, so the readout never stops answering",
        defs[87][:solved]
end

# The whole point of the declaration, driven through the real machinery: a plate is found by what it does.
Suite.define("z 3rd gym: a plate with no sprite is a control, is locatable, and its flip is spoken") do
  pz = PokeAccess::Puzzles
  shipped = load_z_puzzles[87]
  World.clear_events
  begin
    # The plate as the map really has it: no graphic, player-touch, page 0 sets the switch and page 1
    # (self-switch gated) clears it again.
    on_pg = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(121, [142, 142, 0])])
    off_pg = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(121, [142, 142, 1])],
                          :condition => { :self_switch_valid => true, :self_switch_ch => "A" })
    plate = TestGameEvent.new(:id => 43, :x => 10, :y => 17, :pages => [on_pg, off_pg],
                              :active_page => on_pg)
    $game_map.events[43] = plate
    beam = World.event(:kind => :npc, :id => 20, :x => 13, :y => 15)
    beam.character_name = "rayosR"

    pz.register($game_map.map_id, shipped)
    pz.reset_state
    $game_switches[142] = false
    $game_switches[141] = false
    $game_switches[143] = false
    $game_switches[147] = false

    truthy "the puzzle is active, so the info key answers with the switches", pz.active?
    eq "the plate is found and named by the switch it writes", pz.control_label(plate),
       PokeAccess::I18n.t(:gym3_red)
    eq "the beam is still a wall", pz.obstacle_kind(beam), :wall
    eq "and the sound it makes is the control cue, not the silence of a sprite-less event",
       PokeAccess::Audio3D.type_of(plate), :control
    truthy "the plate is a target the pathfinder can route to",
           pz.category_targets.any? { |t| t.x == 10 && t.y == 17 }

    SpeakCapture.clear
    pz.tick
    eq "walking in only snapshots the state, it does not read it out", SpeakCapture.lines, []
    $game_switches[142] = true
    SpeakCapture.clear
    pz.tick
    eq "stepping on the plate announces that switch and no other", SpeakCapture.lines,
       ["#{PokeAccess::I18n.t(:gym3_red)}: #{PokeAccess::I18n.t(:gym3_on)}"]

    SpeakCapture.clear
    pz.read
    eq "and the info key reads all four switches, in the declared order", SpeakCapture.lines,
       ["#{PokeAccess::I18n.t(:gym3_red)}: #{PokeAccess::I18n.t(:gym3_on)}. " \
        "#{PokeAccess::I18n.t(:gym3_blue)}: #{PokeAccess::I18n.t(:gym3_off)}. " \
        "#{PokeAccess::I18n.t(:gym3_green)}: #{PokeAccess::I18n.t(:gym3_off)}. " \
        "#{PokeAccess::I18n.t(:gym3_power)}: #{PokeAccess::I18n.t(:gym3_power_off)}"]
  ensure
    [141, 142, 143, 147].each { |s| $game_switches[s] = false }
    pz.instance_variable_set(:@defs, {})
    pz.reset_state
    World.clear_events
  end
end

# The obstacle list is derived from each event's CURRENT page graphic, and a puzzle switch swaps exactly
# that page: one barrier vanishes and another appears. Cached on the map alone it froze the room as it
# stood when the player walked in, so a barrier raised behind them never warned and one lowered went on
# warning forever -- on this map, where every switch does both at once, that is every barrier in the room.
Suite.define("puzzles: the obstacle list follows the page swap, it does not freeze at the door") do
  pz = PokeAccess::Puzzles
  loc = PokeAccess::Locator
  World.clear_events
  had_interp = loc.instance_variable_get(:@interp_running)
  begin
    beam = World.event(:kind => :npc, :id => 1, :x => 12, :y => 15)
    beam.character_name = ""
    pz.register($game_map.map_id, :kind => :state,
      :watch => [{ :switch => 142, :label => :gym3_red, :on => :gym3_on, :off => :gym3_off }],
      :obstacles => [{ :match => /rayos/i, :kind => :wall }])
    pz.reset_state
    falsy "with the barrier down its tile is clear", pz.obstacle_at?(12, 15)

    beam.character_name = "rayosRojosV"
    falsy "the moment it goes up the cached list has not noticed", pz.obstacle_at?(12, 15)
    pz.forget_obstacles
    truthy "and a refresh sees it", pz.obstacle_at?(12, 15)

    beam.character_name = ""
    truthy "the same the other way: a lowered barrier is still cached as standing",
           pz.obstacle_at?(12, 15)
    loc.instance_variable_set(:@interp_running, true)
    loc.refresh_on_event_end
    falsy "until the event that flipped the switch ends, which is what refreshes it",
          pz.obstacle_at?(12, 15)
  ensure
    loc.instance_variable_set(:@interp_running, had_interp)
    pz.instance_variable_set(:@defs, {})
    pz.reset_state
    World.clear_events
  end
end
