# What the party may do on water joins what the plans and the regions are kept under: a target across water planned
# while nobody can surf is planned again once someone can, and the regions by water are walked afresh once the party
# can climb waterfalls. A full reset reads it afresh, so what it keeps lasts into the next frame.

class WaterMovesTest < PokeAccessTest
  ISLANDS = ["##########",
             "#@~~~~~~.#",
             "##########"]

  test "plans a target across water again once the party can surf" do
    with_tile_world(ISLANDS) do
      surf = false
      with_can(lambda { |m| m == :SURF ? surf : nil }) do
        assert_equal :none, PokeAccess::Routes::Planner.plan(8, 1).kind
        surf = true
        World.next_frame
        assert_equal :surf, PokeAccess::Routes::Planner.plan(8, 1).kind
      end
    end
  end

  test "walks the regions by water afresh once the party can climb waterfalls" do
    with_tile_world(ISLANDS) do
      fall = false
      with_can(lambda { |m| m == :WATERFALL ? fall : nil }) do
        before = PokeAccess::Routes::Regions.water
        fall = true
        World.next_frame
        refute_same before, PokeAccess::Routes::Regions.water
      end
    end
  end

  test "keeps the regions by water a full reset walked afresh, rather than walking them again a frame later" do
    with_tile_world(ISLANDS) do
      surf = false
      with_can(lambda { |m| m == :SURF ? surf : nil }) do
        PokeAccess::Routes::Regions.water
        surf = true
        PokeAccess::World.reset!
        after = PokeAccess::Routes::Regions.water
        World.next_frame
        assert_same after, PokeAccess::Routes::Regions.water
      end
    end
  end

  private

  def with_can(answer)
    fm = PokeAccess::FieldMoves
    fm.singleton_class.send(:alias_method, :can_spec, :can?)
    fm.define_singleton_method(:can?) { |move| answer.call(move) }
    World.next_frame
    yield
  ensure
    fm.singleton_class.send(:alias_method, :can?, :can_spec)
    fm.singleton_class.send(:remove_method, :can_spec)
    World.next_frame
  end
end
