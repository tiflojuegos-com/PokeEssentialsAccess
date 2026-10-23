# The game's own Settings (v19 on) decide two things about a field move, read as ::Settings (the mod has a Settings of
# its own): a Pokemon that can learn the move counts when USE_HM_WITHOUT_LEARNING_THEM is on, and BADGE_FOR_<MOVE>
# names the badge it needs.

class FieldMovesSettingsGdTest < PokeAccessTest
  test "counts a Pokemon that can learn the move when the game lets it use one it does not know" do
    with_setting(:USE_HM_WITHOUT_LEARNING_THEM, true) do
      assert_equal true, PokeAccess::FieldMoves.learn_counts?(learner)
    end
  end

  test "names the badge a move needs from the game's settings" do
    with_setting(:BADGE_FOR_CUT, 1) do
      assert_equal 1, PokeAccess::FieldMoves.badge_for(:CUT)
    end
  end

  private

  def learner
    pl = Object.new
    def pl.get_pokemon_can_learn_move(_move); true; end
    pl
  end

  def with_setting(name, value)
    ::Settings.const_set(name, value)
    yield
  ensure
    ::Settings.send(:remove_const, name) if ::Settings.const_defined?(name, false)
  end
end
