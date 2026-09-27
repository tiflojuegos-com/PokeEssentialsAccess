# A synthetic target (surface, mark, map edge) has no event id even where every object answers to id, as under Ruby
# 1.8.7 (Object#id aliases object_id): it sorts by its tile and takes no tag.
Suite.define("locator: a synthetic target has no event id, even where every object answers to id") do
  loc = PokeAccess::Locator
  surf = PokeAccess::Locator::SurfaceTarget.new(4, 9, "Agua", :surf_water)
  def surf.id; object_id; end
  ev = World.event(:name => "EV003", :id => 3, :x => 4, :y => 9)

  eq "a map event is known by its event id", loc.event_id_of(ev), 3
  eq "a surface has none, whatever it answers to", loc.event_id_of(surf), nil
  eq "so its fixed number sorts by its tile", loc.stable_key(surf), [1, 4, 9]
  eq "and the event's by its id", loc.stable_key(ev), [0, 3]
  eq "no category override is looked up for a surface", loc.tag_override(surf), nil
  falsy "and it is never taken for a hidden event", loc.tag_hidden?(surf)
end
