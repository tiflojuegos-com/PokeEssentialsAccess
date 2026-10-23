# Soulstones 2's blocking windows, the tutorial popups and the boss's Achievement Points scoreboard, are read as they
# open, queued, markup and line breaks gone, the keys their hints name said as the player has them bound.

# The game's own windows, which block until dismissed: the text, and the scene they are raised over.
def pbTutorialWindow(text, scene = nil); [text, scene]; end
def pbBottomRightWindow(text, scene = nil); [text, scene]; end

class Ss2NoticesGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "soulstones2", "notices.rb")
  SCOREBOARD = "<b>A boss was defeated!</b>\nBattle style points:<r>+3\r\nDifficulty mode points:<r>+4\r\n" \
               "<b>Total AP earned:<r>7</b>"

  # Evaluates the profile's notices once per process from an empty table of hint letters, and answers the letters it
  # declares; the table and the profile list are put back after.
  def self.load_notices
    letters = PokeAccess::Config.key_hint_letters
    profiles = PokeAccess::Game.profiles.dup
    PokeAccess::Config.key_hint_letters = {}
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
    PokeAccess::Config.key_hint_letters
  ensure
    PokeAccess::Config.key_hint_letters = letters
    PokeAccess::Game.profiles.replace(profiles)
  end
  LETTERS = load_notices

  test "a tutorial popup is read as it opens, queued" do
    pbTutorialWindow("Select areas will have a Raid Den where you can confront a boss-level Pokemon.")
    assert_equal [["Select areas will have a Raid Den where you can confront a boss-level Pokemon.", false]],
                 SpeakCapture.log
  end

  test "the boss scoreboard is read line after line, its markup and line breaks gone, queued" do
    pbBottomRightWindow(SCOREBOARD)
    assert_equal [["A boss was defeated! Battle style points:+3 Difficulty mode points:+4 Total AP earned:7", false]],
                 SpeakCapture.log
  end

  test "a window with no text says nothing" do
    { :pbTutorialWindow => "", :pbBottomRightWindow => nil }.each do |window, text|
      send(window, text)
      assert_nothing_spoken "#{window}(#{text.inspect})"
    end
  end

  test "the key a tutorial asks for is said as the player has bound it" do
    with_keys(LETTERS, :y => 0x4B) { pbTutorialWindow("You can Quick Save by pressing S.") }
    assert_equal [["You can Quick Save by pressing K.", false]], SpeakCapture.log
  end

  private

  # Runs the block with these hint letters and the buttons rebound as given, both put back after.
  def with_keys(letters, rebinds)
    was = [PokeAccess::Config.key_hint_letters, PokeAccess::Config.rebinds]
    PokeAccess::Config.key_hint_letters = letters
    PokeAccess::Config.rebinds = rebinds
    yield
  ensure
    PokeAccess::Config.key_hint_letters, PokeAccess::Config.rebinds = was
  end
end
