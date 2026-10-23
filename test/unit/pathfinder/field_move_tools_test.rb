# A game's tools for a field move (FieldMoves.register_tool, the profile DSL's field_move_tool): the whole set in the
# bag stands in for a Pokemon that knows the move, the move's badge still asked; with only, the set is the one way,
# and a Pokemon that knows the move no longer helps.
class FieldMoveToolsTest < PokeAccessTest
  test "a whole set of tools stands in for the move, the badge still asked" do
    with_world(false, true) do |bag|
      fm.register_tool(:CUT, [:GOLDENAXE, :HM01])
      bag.push(:GOLDENAXE)
      assert_equal false, fm.can?(:CUT)
      bag.push(:HM01)
      assert_equal true, fm.can?(:CUT)
    end
    with_world(false, false) do |bag|
      bag.push(:GOLDENAXE, :HM01)
      assert_equal false, fm.can?(:CUT)
    end
  end

  test "tools that are the one way leave a Pokemon that knows the move out" do
    with_world(true, true) do |bag|
      fm.register_tool(:SURF, [:SURFMONTURA], true)
      assert_equal false, fm.can?(:SURF)
      bag.push(:SURFMONTURA)
      assert_equal true, fm.can?(:SURF)
    end
  end

  private

  def fm; PokeAccess::FieldMoves; end

  # Runs the block with an empty bag it fills (yielded), the party knowing every move or none and every badge won or
  # none, all put back afterwards; the tools registered inside go with the test reset.
  def with_world(knows, badge)
    keep = [[:knows?, fm.method(:knows?)], [:badge_ok?, fm.method(:badge_ok?)]]
    bag_was = $PokemonBag
    items = []
    $PokemonBag = Object.new
    $PokemonBag.define_singleton_method(:pbQuantity) { |it| items.include?(it) ? 1 : 0 }
    fm.define_singleton_method(:knows?) { |_m| knows }
    fm.define_singleton_method(:badge_ok?) { |_m| badge }
    yield items
  ensure
    keep.each { |m, meth| fm.define_singleton_method(m, meth) }
    $PokemonBag = bag_was
  end
end
