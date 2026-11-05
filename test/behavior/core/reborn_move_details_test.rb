# Reborn's move details panel of the fight menu, which the game reads to itself, said through the relay
# (games/reborn/own_voice.rb). In a process of its own: a class under the battle scene's name would stand in the way of the
# other tests' stand-ins, and their hooks in the way of this one.
class RebornMoveDetailsTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil

    # The game's reader, which the relay follows.
    def tts(text, _interrupt = false); text; end

    # The panel, opened with A: its keyword is the engine's own.
    class PokeBattle_Scene
      def pbDrawMoveDetails(_battler, _index, _zmove, new: false)
        tts("Tackle, Physical, 40 power, 100 accuracy, A full-body charge.")
        new
      end
    end
  RUBY

  PLAY = <<-'RUBY'
    def open_panel; PokeBattle_Scene.allocate.pbDrawMoveDetails(nil, 0, false, new: true); end

    probe(:panel) { said { probe(:kept) { open_panel } } }
  RUBY

  profile "reborn", WORLD, PLAY

  test "says the panel, queued, and passes on its keyword" do
    assert_equal [["Tackle, Physical, 40 power, 100 accuracy, A full-body charge.", false]], played(:panel)
    assert_equal true, played(:kept)
  end
end
