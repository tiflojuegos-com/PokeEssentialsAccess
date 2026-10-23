# The randomizer's progress bar (games/infinitefusion_common/shuffle_progress.rb): what it shuffles and its percentage
# as it opens, then the percentage on reaching each quarter, never every repaint of a long shuffle.

# The game's progress bar, reduced to its paint: the text and the percentage, painted as it opens and on each step.
class ShuffleProgressBar
  def initialize(text = "Shuffling...")
    @text = text
    drawProgressText(0)
  end

  def progress=(progress)
    drawProgressText(progress)
  end

  def drawProgressText(progress)
    pbDrawTextPositions(nil, [[@text, 12, 0], [format("%.0f%%", progress * 100), 12, 24]])
  end
end

class IfShuffleProgressGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_common", "shuffle_progress.rb")

  # Evaluates the profile file once, as boot does, its hook bound to the stand-in above.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  test "opening, it says what it shuffles and where it starts, queued" do
    ShuffleProgressBar.new("Shuffling wild Pokémon...")
    assert_equal [["Shuffling wild Pokémon... 0%", false]], SpeakCapture.log
  end

  test "says the percentage of each repaint that reaches a new quarter, queued" do
    bar = ShuffleProgressBar.new("Shuffling wild Pokémon...")
    SpeakCapture.clear
    [0.1, 0.2, 0.26, 0.3, 0.49, 0.5, 0.99, 1.0].each { |p| bar.progress = p }
    assert_equal [["26%", false], ["50%", false], ["99%", false], ["100%", false]], SpeakCapture.log
  end

  test "each bar counts its own quarters" do
    ShuffleProgressBar.new("Shuffling items...").progress = 0.6
    bar = ShuffleProgressBar.new("Shuffling gyms...")
    SpeakCapture.clear
    bar.progress = 0.3
    assert_equal ["30%"], SpeakCapture.lines
  end
end
