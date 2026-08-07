# Audio3D.type_of is the decision that answers "WHICH sound does this event make". It is a projection of
# the locator's classification onto the sound vocabulary, and its ORDER of tests is the contract: the first
# rule that matches wins, so moving one line turns a door into an object or silences a puzzle control. A
# blind player learns these cues by heart, so a swap is worse than silence -- they walk into the wrong tile.
# None of this needs the dll: type_of only reads event data through Locator/Puzzles/Tags.

# The base readings, each against a near-identical event that must read differently. The pairs are chosen so
# that only ONE input changes between them (the sprite, or whether the event answers the action button).
Suite.define("audio3d: type_of gives each kind of event the cue the player learned") do
  a3d = PokeAccess::Audio3D
  World.clear_events

  eq "a warp door is a door", a3d.type_of(World.event(:kind => :door, :id => 1, :x => 4, :y => 5)), :door

  # Same transfer event, only the sprite differs: a warp-pad graphic must not sound like a hinged door.
  plain = World.event(:kind => :door, :id => 2, :x => 5, :y => 4)
  plain.character_name = "boy"
  pad = World.event(:kind => :door, :id => 3, :x => 6, :y => 4)
  pad.character_name = "portal"
  eq "a transfer with an ordinary sprite is still a door", a3d.type_of(plain), :door
  eq "the same transfer with a warp-pad sprite is a teleporter", a3d.type_of(pad), :teleporter

  eq "a talkable person is an npc", a3d.type_of(World.event(:kind => :trainer, :id => 4, :x => 7, :y => 5)), :npc

  # Same person-shaped event, object sprite: the "objects" cue exists so the player can tell furniture from
  # people without asking, and event_category keys that on the sprite alone.
  thing = World.event(:kind => :trainer, :id => 5, :x => 8, :y => 5)
  thing.character_name = "objeto3"
  eq "the same event with an object sprite is an object", a3d.type_of(thing), :object

  # The phantom-NPC guard: a graphic alone must not ping, or every decorative sprite becomes a person the
  # player walks over to and cannot interact with. Only the command list differs between these two.
  quiet_pg = TestPage.new(:trigger => 0, :sprite => "hiker")
  quiet = TestGameEvent.new(:id => 6, :x => 9, :y => 5, :pages => [quiet_pg], :active_page => quiet_pg)
  talky_pg = TestPage.new(:trigger => 0, :sprite => "hiker", :list => [TestCmd.new(101, ["Hola"])])
  talky = TestGameEvent.new(:id => 7, :x => 10, :y => 5, :pages => [talky_pg], :active_page => talky_pg)
  eq "a decorative sprite that answers nothing is not an emitter", a3d.type_of(quiet), nil
  eq "the same sprite that talks back is an npc", a3d.type_of(talky), :npc

  # Signs are read by the locator, not pinged: they have no graphic, and a soundscape full of sign pings
  # would drown the people and doors the player is actually navigating by.
  eq "a bare sign makes no sound", a3d.type_of(World.event(:kind => :sign, :id => 8, :x => 4, :y => 6)), nil

  World.clear_events
end

# The player's own override (Ctrl+K) is the escape hatch for a game whose events the automatic reading gets
# wrong. It is checked FIRST for a reason: if any automatic rule could outrank it, the player would retag an
# event, hear no change, and have no way to fix their map. Hiding must silence the emitter outright.
Suite.define("audio3d: a player tag outranks every automatic reading of an event") do
  a3d = PokeAccess::Audio3D
  prev_tags = PokeAccess::Tags.instance_variable_get(:@tags)
  begin
    World.clear_events
    person = World.event(:kind => :trainer, :id => 1, :x => 6, :y => 5)
    door = World.event(:kind => :door, :id => 2, :x => 7, :y => 5)
    mid = $game_map.map_id
    eq "untagged, the person reads as a person", a3d.type_of(person), :npc
    eq "untagged, the door reads as a door", a3d.type_of(door), :door

    PokeAccess::Tags.instance_variable_set(:@tags, { mid => { 1 => { "cat" => "exits" },
                                                              2 => { "cat" => "people" } } })
    eq "tagged as an exit, the person sounds like a door", a3d.type_of(person), :door
    eq "tagged as a person, the door sounds like an npc", a3d.type_of(door), :npc

    PokeAccess::Tags.instance_variable_set(:@tags, { mid => { 1 => { "cat" => "objects" },
                                                              2 => { "cat" => "signs" } } })
    eq "tagged as an object, the person sounds like an object", a3d.type_of(person), :object
    eq "tagged into a category with no cue, an event goes quiet", a3d.type_of(door), nil

    PokeAccess::Tags.instance_variable_set(:@tags, { mid => { 1 => { "hidden" => true } } })
    eq "a hidden event is dropped from the soundscape", a3d.type_of(person), nil
    eq "while its untagged neighbour keeps sounding", a3d.type_of(door), :door
  ensure
    PokeAccess::Tags.instance_variable_set(:@tags, prev_tags)
    World.clear_events
  end
end

# Puzzle readings come before the generic ones: a moving hazard on a ship deck IS a person-sized sprite, so
# if the sprite reading won first the player would hear "person" for the thing about to shove them off the
# map. Each case is asserted twice -- with the puzzle registered and with it gone -- so the assert can only
# pass by honouring the puzzle, not by accident.
Suite.define("audio3d: puzzle obstacles and controls outrank the sprite reading") do
  a3d = PokeAccess::Audio3D
  begin
    World.clear_events
    mover = World.event(:kind => :trainer, :id => 1, :x => 6, :y => 5)
    mover.character_name = "sharpedo"
    block = World.event(:kind => :trainer, :id => 2, :x => 7, :y => 5)
    block.character_name = "roca_gigante"

    # A crank that ALSO carries a map transfer: the control cue must win, or the player hears "door" for the
    # lever that solves the room and never finds it.
    pg = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(122, [132, 132, 0, 0, 1]),
                                                              TestCmd.new(201, [0, 5, 1, 1])])
    crank = TestGameEvent.new(:id => 3, :x => 8, :y => 5, :pages => [pg], :active_page => pg)
    $game_map.events[3] = crank

    PokeAccess::Puzzles.register($game_map.map_id, :kind => :state,
      :watch => [{ :var => 132, :label => :ship_crank_red }],
      :obstacles => [{ :match => /sharpedo/i, :kind => :mover }, { :match => /roca/i, :kind => :wall }])
    PokeAccess::Puzzles.reset_state
    eq "a moving obstacle is a trap, not the person its sprite looks like", a3d.type_of(mover), :trap
    eq "a static puzzle obstacle is a hazard", a3d.type_of(block), :hazard
    eq "a control that also warps is a control", a3d.type_of(crank), :control
    truthy "and the map declares movers, so the tick retracks them", PokeAccess::Puzzles.has_movers?

    PokeAccess::Puzzles.instance_variable_set(:@defs, {})
    PokeAccess::Puzzles.reset_state
    eq "off the puzzle map the same sprite falls back to a person", a3d.type_of(mover), :npc
    eq "and so does the obstacle", a3d.type_of(block), :npc
    eq "while the crank falls back to its transfer", a3d.type_of(crank), :door
    falsy "with no movers left to retrack", PokeAccess::Puzzles.has_movers?
  ensure
    PokeAccess::Puzzles.instance_variable_set(:@defs, {})
    PokeAccess::Puzzles.reset_state
    World.clear_events
  end
end

# Registered hazard sprites (a game's lasers/beams) and invisible conveyor tiles both get their own cue
# because both HURT: one damages, the other silently shoves the player off their route. The conveyor test
# runs on its own map id because push tiles are cached per map, and it is paired with a wandering NPC's own
# move route -- the shape that must NOT be mistaken for a conveyor, or every walking NPC would boing.
Suite.define("audio3d: registered hazards and conveyor tiles keep their own cues") do
  a3d = PokeAccess::Audio3D
  saved_hazards = PokeAccess::Locator::HAZARDS.dup
  prev_map = $game_map.map_id
  begin
    World.clear_events
    beam = World.event(:kind => :trainer, :id => 1, :x => 6, :y => 5)
    beam.character_name = "laser_rojo"
    eq "an unregistered sprite is just a person", a3d.type_of(beam), :npc
    PokeAccess::Locator.register_hazard(/laser/i, :loc_hazard_spec)
    eq "the same sprite registered as a hazard sounds like one", a3d.type_of(beam), :hazard

    $game_map.map_id = 777
    World.clear_events
    route = Struct.new(:list).new([Struct.new(:code).new(1), Struct.new(:code).new(4)])
    conv_pg = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(209, [-1, route])])
    conveyor = TestGameEvent.new(:id => 1, :x => 6, :y => 6, :pages => [conv_pg], :active_page => conv_pg)
    walk_pg = TestPage.new(:trigger => 1, :sprite => "boy", :list => [TestCmd.new(209, [3, route])])
    walker = TestGameEvent.new(:id => 2, :x => 7, :y => 6, :pages => [walk_pg], :active_page => walk_pg)
    $game_map.events[1] = conveyor
    $game_map.events[2] = walker

    eq "an invisible tile that walks the PLAYER is a push tile", a3d.type_of(conveyor), :push
    eq "an npc walking itself is not (it would boing on every step)", a3d.type_of(walker), nil
  ensure
    PokeAccess::Locator::HAZARDS.replace(saved_hazards)
    $game_map.map_id = prev_map
    World.clear_events
  end
end

# desk_bypass is the exception that keeps a Pokemon Center usable with line-of-sight ON: the nurse stands
# behind an impassable counter, so the raycast calls her occluded and hide mode would delete the single most
# important emitter on the map. It is deliberately narrow -- only service desks, only within the configured
# range -- so the exception cannot be abused to leak every object through walls.
Suite.define("audio3d: only a near service desk bypasses line of sight") do
  a3d = PokeAccess::Audio3D
  prev_desk = PokeAccess::Config.audio3d_desk_range
  begin
    World.clear_events
    nurse = World.event(:kind => :trainer, :id => 1, :x => 6, :y => 5)
    nurse.character_name = "nurse"
    guy = World.event(:kind => :trainer, :id => 2, :x => 7, :y => 5)

    PokeAccess::Config.audio3d_desk_range = 2
    truthy "the clerk is heard across the counter", a3d.desk_bypass?(nurse, 1)
    truthy "still at the edge of the desk range", a3d.desk_bypass?(nurse, 2)
    falsy "but not one tile beyond it", a3d.desk_bypass?(nurse, 3)
    falsy "an ordinary person never bypasses a wall", a3d.desk_bypass?(guy, 1)

    PokeAccess::Config.audio3d_desk_range = 0
    falsy "and the whole exception can be switched off", a3d.desk_bypass?(nurse, 1)
  ensure
    PokeAccess::Config.audio3d_desk_range = prev_desk
    World.clear_events
  end
end

# The optional "only what the keys can reach" filter. The two classifiers agree on everything with a
# dedicated predicate (doors, hazards, controls, tags) and disagree on exactly one shape: an event drawn
# with a TILE graphic and a touch trigger, which pings here but is in no locator category. Those fire on
# contact, so the default keeps pinging them; the filter is for a player who wants the two lists to match.
Suite.define("audio3d: the locatable filter silences only the events the keys cannot reach") do
  a3d = PokeAccess::Audio3D
  prev = PokeAccess::Config.sonar_only_locatable
  begin
    World.clear_events
    tile_pg = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(101, ["Hola"])])
    touch = TestGameEvent.new(:id => 1, :x => 6, :y => 5, :pages => [tile_pg], :active_page => tile_pg)
    def touch.tile_id; 384; end
    $game_map.events[1] = touch
    door = World.event(:kind => :door, :id => 2, :x => 7, :y => 5)

    PokeAccess::Config.sonar_only_locatable = false
    eq "off, a tile-graphic touch event pings as an object", a3d.type_of(touch), :object
    falsy "even though the keys never list it", PokeAccess::Locator.in_category?(touch, :all)

    PokeAccess::Config.sonar_only_locatable = true
    eq "on, that same event goes quiet", a3d.type_of(touch), nil
    eq "and a door is untouched by the filter, because the keys do reach it", a3d.type_of(door), :door
  ensure
    PokeAccess::Config.sonar_only_locatable = prev
    World.clear_events
  end
end

# The census the diagnostic prints. It must count with the filter OFF: a player who turns the filter on and
# then opens the diagnostic needs to see how big the gap IS, not zero because they just silenced it.
Suite.define("audio3d: the reach census measures the gap with the filter off") do
  a3d = PokeAccess::Audio3D
  prev = PokeAccess::Config.sonar_only_locatable
  begin
    World.clear_events
    tile_pg = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(101, ["Hola"])])
    touch = TestGameEvent.new(:id => 1, :x => 6, :y => 5, :pages => [tile_pg], :active_page => tile_pg)
    def touch.tile_id; 384; end
    $game_map.events[1] = touch
    World.event(:kind => :door, :id => 2, :x => 7, :y => 5)

    PokeAccess::Config.sonar_only_locatable = false
    eq "off, two ping and one is out of reach", a3d.reach_census, "2 pingan, 1 fuera del localizador"

    PokeAccess::Config.sonar_only_locatable = true
    eq "on, the census still reports the same gap", a3d.reach_census, "2 pingan, 1 fuera del localizador"
    eq "and the filter is left as the player set it", PokeAccess::Config.sonar_only_locatable, true
  ensure
    PokeAccess::Config.sonar_only_locatable = prev
    World.clear_events
  end
end
