# Royal's egg-move tutor (games/royal/egg_tutor.rb) replaces the move reminder's main without calling it, so the
# reminder's opening read hooks its own main: the first move is read each time it opens.
module UI
  # The tutor down to what its hook wraps: main, the screen's whole run.
  class EggMoveTutor
    def main; :taught; end
  end
end
egg_tutor_path = File.join(Harness::ROOT, "games", "royal", "egg_tutor.rb")
eval(Harness.source(egg_tutor_path), TOPLEVEL_BINDING, egg_tutor_path)

class RoyalEggTutorGdTest < PokeAccessTest
  test "reads the first move as it opens, and the tutor runs as the game's" do
    tutor = tutor_with([[:TACKLE, nil], [:EMBER, nil]])
    assert_equal :taught, tutor.main, "main's own result"
    assert_equal [[PokeAccess::UIV21.move_from_entry([:TACKLE, nil]), true]], SpeakCapture.log
  end

  test "reads the first move again on every opening" do
    tutor = tutor_with([[:TACKLE, nil], [:EMBER, nil]])
    2.times { tutor.main }
    first = PokeAccess::UIV21.move_from_entry([:TACKLE, nil])
    assert_equal [first, first], SpeakCapture.lines
  end

  test "opens in silence with no moves to teach" do
    [[], nil].each do |moves|
      SpeakCapture.clear
      tutor_with(moves).main
      assert_nothing_spoken "for moves #{moves.inspect}"
    end
  end

  private

  # A tutor whose list holds moves ([move, label] pairs), as the screen keeps them in @moves.
  def tutor_with(moves)
    tutor = UI::EggMoveTutor.new
    tutor.instance_variable_set(:@moves, moves)
    tutor
  end
end
