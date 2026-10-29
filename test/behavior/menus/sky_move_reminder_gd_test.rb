# The move reminder of Sky's base (core/menus/v21/move_reminder_open_v21.rb and UIV21's rows): its first move read as
# the screen fades in, its egg-move tutor's own main included, and a machine row's tag said as the relearner paints
# it, through the game's translation (games/skyflyer_common/relearner_labels.rb, loaded with Anil's profile).

# The screens down to what their opening reads: the base screen fades in with start_screen, the reminder keeps its
# Pokemon and moves and runs start_screen first in its main, as the game's do.
module UI
  class BaseScreen
    def start_screen; @faded = true; end unless method_defined?(:start_screen)
  end

  class MoveReminder < BaseScreen
    def initialize(pokemon, moves); @pokemon = pokemon; @moves = moves; end
    def main; start_screen; :done; end
  end
end
reminder_open_path = File.join(Harness::ROOT, "core", "menus", "v21", "move_reminder_open_v21.rb")
eval(Harness.source(reminder_open_path), TOPLEVEL_BINDING, reminder_open_path)

class SkyMoveReminderGdTest < PokeAccessTest
  # Sky's egg-move tutor as far as its opening goes: a reminder with a main of its own, which fades in first too.
  class Tutor < UI::MoveReminder
    def main; start_screen; :taught; end
  end

  MOVES = [[:TACKLE, "Nv. 1"], [:EMBER, "Nv. 5"]]

  test "a reminder reads its first move as it fades in, interrupting" do
    assert_equal :done, UI::MoveReminder.new(nil, MOVES).main, "main's own result"
    assert_equal [[row(MOVES[0]), true]], SpeakCapture.log
  end

  test "a reminder with a main of its own, the egg-move tutor, reads its first move as it fades in" do
    assert_equal :taught, Tutor.new(nil, [[:TACKLE, nil], [:EMBER, nil]]).main, "main's own result"
    assert_equal [row([:TACKLE, nil])], SpeakCapture.lines
  end

  test "every opening reads its first move again" do
    reminder = UI::MoveReminder.new(nil, MOVES)
    2.times { reminder.main }
    assert_equal [row(MOVES[0])] * 2, SpeakCapture.lines
  end

  test "a reminder with no moves opens in silence" do
    [[], nil].each do |moves|
      SpeakCapture.clear
      UI::MoveReminder.new(nil, moves).main
      assert_nothing_spoken "for moves #{moves.inspect}"
    end
  end

  test "a machine row says the word the relearner paints for its tag before the move" do
    bare = row([:TACKLE, ""])
    assert_equal "MT. #{bare}", row([:TACKLE, :TM]), "a TM row"
    assert_equal "MO. #{bare}", row([:TACKLE, :HM]), "an HM row"
  end

  test "a machine row says the words an English build's translation gives" do
    bare = row([:TACKLE, ""])
    with_intl("MT" => "TM", "MO" => "HM") do
      assert_equal "TM. #{bare}", row([:TACKLE, :TM]), "a TM row"
      assert_equal "HM. #{bare}", row([:TACKLE, :HM]), "an HM row"
    end
  end

  test "a level row keeps its label as written" do
    bare = row([:TACKLE, ""])
    assert_equal "Nv. 5. #{bare}", row([:TACKLE, "Nv. 5"])
  end

  private

  # The reminder's spoken row for a [move, label] entry.
  def row(entry)
    PokeAccess::UIV21.move_from_entry(entry)
  end
end
