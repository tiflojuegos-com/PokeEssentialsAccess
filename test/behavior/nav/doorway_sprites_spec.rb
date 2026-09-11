# A door drawn with a sprite that opens on the action button, a warp pad that asks before it takes the
# player, a floor arrow painted at an exit: the map data of the surveyed games holds a couple of dozen of
# the first, a hundred and fifty of the second and over a thousand painted doors and arrows, and all of
# them were listed among the PEOPLE, named after their sprite file, because an action-button transfer with a
# sprite was read as a person taking the player somewhere. The sprite is what tells the two apart: the
# sailor and the Abra owner keep a person's sprite, the passage a doorway's. The names cut both ways: a
# soldier called "Exit" who only talks is a person, and "Teleportation Master" is the NPC, not the pad.
def doorway_case(id, sprite, trigger, list)
  page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => list)
  ev = TestGameEvent.new(:id => id, :x => 3 + id, :y => 6, :name => "EV00#{id}", :pages => [page], :active_page => page)
  $game_map.events[id] = ev
  PokeAccess::Locator.clear_verdicts
  ev
end

Suite.define("locator: a doorway sprite is an exit however it is triggered, a person's sprite stays a person") do
  loc = PokeAccess::Locator
  a3d = PokeAccess::Audio3D
  begin
    World.clear_events
    ask = TestCmd.new(101, ["Go in?"])
    warp = TestCmd.new(201, [0, 5, 1, 1])

    door = doorway_case(1, "doors3", 0, [ask, warp])
    truthy "an action-button door with a confirmation is an exit", loc.transfer_event?(door)
    truthy "listed among the exits", loc.in_category?(door, :exits)
    falsy "and no longer among the people", loc.in_category?(door, :people)
    falsy "nor repeated among the objects, tile by tile, under its sprite's name", loc.in_category?(door, :objects)
    eq "the sonar gives it the door cue", a3d.type_of(door), :door

    pad = doorway_case(2, "Umbral", 0, [ask, warp])
    truthy "a warp pad that asks first is an exit too", loc.in_category?(pad, :exits)
    falsy "and only an exit", loc.in_category?(pad, :objects) || loc.in_category?(pad, :people)
    eq "with the teleporter cue", a3d.type_of(pad), :teleporter

    hidden = doorway_case(6, "", 0, [ask, warp])
    truthy "an invisible action-button warp is an exit", loc.in_category?(hidden, :exits)
    falsy "and not an extra as well", loc.in_category?(hidden, :extras)

    sailor = doorway_case(3, "trchar036", 0, [ask, warp])
    falsy "a person who takes the player somewhere is not an exit", loc.transfer_event?(sailor)
    truthy "they stay a person", loc.in_category?(sailor, :people)
    eq "and ping as one", a3d.type_of(sailor), :npc

    arrow = doorway_case(4, "flecha", 0, [])
    falsy "a painted floor arrow with no commands is not an exit", loc.transfer_event?(arrow)
    falsy "nor a person nobody can talk to", loc.in_category?(arrow, :people)
    truthy "it is an object, named after its sprite", loc.in_category?(arrow, :objects)

    far = doorway_case(5, "doors1", 1, [TestCmd.new(201, [0, 999, 1, 1])])
    match "an exit named EV### by the editor is spoken as an exit", loc.target_name(far).to_s, /salida/i
    truthy "never by its editor name", !(loc.target_name(far).to_s =~ /EV00/i)

    guard = doorway_case(7, "trainer_INFANTRY_M", 0, [ask])
    guard.name = "Exit"
    PokeAccess::Locator.clear_verdicts
    falsy "a soldier the editor named Exit, who only talks, is not an exit", loc.transfer_event?(guard)
    truthy "he stays a person", loc.in_category?(guard, :people)

    taxi = doorway_case(8, "trainer_TELEPORTER_Honchkrow", 0, [ask])
    falsy "the NPC who teleports the player by common event is no pad", loc.transfer_event?(taxi)
    truthy "he is a person too", loc.in_category?(taxi, :people)
    eq "and pings as one", a3d.type_of(taxi), :npc

    hoopa = doorway_case(11, "HOOPA", 0, [ask, warp])
    falsy "the Hoopa character who talks and then warps is a person, not its ring", loc.transfer_event?(hoopa)
    truthy "listed among the people", loc.in_category?(hoopa, :people)
    ring = doorway_case(12, "Npc-Hoopa Rings", 0, [ask, warp])
    truthy "the ring itself is the exit", loc.in_category?(ring, :exits)
    eq "with the teleporter cue", a3d.type_of(ring), :teleporter
  ensure
    World.clear_events
    PokeAccess::Locator.clear_verdicts
  end
end
