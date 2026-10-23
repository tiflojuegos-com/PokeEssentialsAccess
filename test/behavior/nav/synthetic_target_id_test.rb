# A synthetic target (a surface, a mark, a map edge, a puzzle's spot) has no event id even answering to id, as every
# object does under Ruby 1.8.7: it is known by what it is, ranks where its source lists it and takes no tag.
class SyntheticTargetIdTest < PokeAccessTest
  Loc = PokeAccess::Locator
  Spot = PokeAccess::Locator::SurfaceTarget

  test "knows a map event by its event id, and a synthetic target or none by no id at all" do
    ev = World.event(:name => "EV003", :id => 3, :x => 4, :y => 9)
    [[ev, 3], [answering_id(Spot.new(4, 9, "Agua", :surf_water)), nil],
     [answering_id(Spot.new(4, 0, "salida a Ruta 5", nil, 5)), nil], [nil, nil]].each do |t, want|
      got = Loc.event_id_of(t)
      want.nil? ? assert_nil(got, "for #{t.inspect}") : assert_equal(want, got, "for #{t.inspect}")
    end
  end

  test "knows each kind of target by what it is" do
    ev = World.event(:id => 3, :x => 4, :y => 9)
    [[ev, [:event, 3]],
     [Spot.new(4, 9, "Agua", :surf_water, :surface), [:surf_water, :surface]],
     [Spot.new(4, 9, "baldosa trampa", :op_trap, :surface), [:op_trap, :surface]],
     [Spot.new(4, 9, "punto de buceo", :surf_dive, :surface), [:surf_dive, :surface]],
     [Spot.new(4, 9, "lugar para emerger", :surf_surface, :surface), [:surf_surface, :surface]],
     [Spot.new(4, 9, "uno", :mark), [:mark, 4, 9]],
     [Spot.new(4, 0, "salida a Ruta 5", nil, 5), [:edge, 5]],
     [Spot.new(4, 9, "palanca", :puzzle_control, 12), [:puzzle_control, 12]],
     [Spot.new(4, 9, "casilla", :puzzle_cell), [:puzzle_cell, 4, 9]]].each do |t, want|
      assert_equal want, Loc.identity(answering_id(t)), "for #{t.inspect}"
    end
  end

  test "ranks events by id, map edges by their map, and the rest where their source lists them" do
    ev = World.event(:id => 3, :x => 4, :y => 9)
    [[ev, 5, [0, 3]],
     [Spot.new(4, 0, "salida a Ruta 5", nil, 5), 7, [1, 5]],
     [Spot.new(4, 9, "Agua", :surf_water), 5, [2, 5]],
     [Spot.new(4, 9, "uno", :mark), 0, [2, 0]],
     [Spot.new(4, 9, "palanca", :puzzle_control, 12), 2, [2, 2]]].each do |t, i, want|
      assert_equal want, Loc.rank_key(answering_id(t), i), "for #{t.inspect} listed at #{i}"
    end
  end

  test "takes no category or hiding of the player's for a synthetic target, even answering to a tagged event's id" do
    ev = World.event(:id => 3, :x => 4, :y => 9)
    surf = answering_id(Spot.new(4, 9, "Agua", :surf_water), 3)
    PokeAccess::Tags.set_category($game_map.map_id, 3, :people)
    PokeAccess::Tags.set_hidden($game_map.map_id, 3, true)
    assert_equal [:people, true, nil, false],
                 [Loc.tag_override(ev), Loc.tag_hidden?(ev), Loc.tag_override(surf), Loc.tag_hidden?(surf)]
  ensure
    PokeAccess::Tags.delete($game_map.map_id, 3)
  end

  private

  # The target, a synthetic one answering to id as every object does under Ruby 1.8.7: with its object id, or the id
  # given.
  def answering_id(t, id = nil)
    t.define_singleton_method(:id) { id || object_id } if t.is_a?(Spot)
    t
  end
end
