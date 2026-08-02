# Collapsing a wide doorway into ONE target. In RPG Maker a two- or three-tile door is two or three
# separate events leading to the same place; without this the locator would offer "exit, exit, exit" and
# the player would have to walk past two of them to leave through one.
#
# This had NO coverage at all, which is how a rewrite of the whole function could pass CI. What it pins is
# the behaviour, not the implementation: which events survive, and which one of a group is the survivor.
Suite.define("locator: a wide doorway collapses to one target, and nothing else is touched") do
  loc = PokeAccess::Locator
  World.clear_events

  # Three door tiles side by side (the builder gives them all the same destination), plus two events that
  # are not doors at all.
  d1 = World.event(:id => 1, :kind => :door, :x => 10, :y => 5)
  d2 = World.event(:id => 2, :kind => :door, :x => 11, :y => 5)
  d3 = World.event(:id => 3, :kind => :door, :x => 12, :y => 5)
  npc = World.event(:id => 4, :kind => :npc, :x => 3, :y => 3)
  sign = World.event(:id => 5, :kind => :sign, :x => 4, :y => 3)

  out = loc.cluster_exits([d1, d2, d3, npc, sign], 10, 5)
  eq "the three door tiles become one target, and the other two survive", out.length, 3
  truthy "the npc is still there", out.include?(npc)
  truthy "and the sign", out.include?(sign)
  eq "the surviving door tile is the one nearest the player", out.find { |e| [d1, d2, d3].include?(e) }, d1

  # Standing at the far end, the survivor changes: it is always the one you would actually walk into.
  out = loc.cluster_exits([d1, d2, d3, npc, sign], 12, 5)
  eq "from the other side, the nearest tile wins instead",
     out.find { |e| [d1, d2, d3].include?(e) }, d3

  # Two doors to the same map but on opposite sides of the room are NOT one doorway: the merge test also
  # demands they be adjacent, so a building with two entrances still offers both.
  far = World.event(:id => 6, :kind => :door, :x => 25, :y => 5)
  out = loc.cluster_exits([d1, d2, d3, far], 10, 5)
  eq "a door across the room stays its own target", out.length, 2
  truthy "and it is the far one that was kept apart", out.include?(far)

  # Degenerate inputs must come back untouched rather than empty: this list IS the locator's target list.
  eq "a single event is returned as-is", loc.cluster_exits([npc], 0, 0), [npc]
  eq "and a list with no doors at all keeps every one of them",
     loc.cluster_exits([npc, sign], 0, 0).length, 2
  World.clear_events
end
