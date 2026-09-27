# The randomizer's progress bar (ShuffleProgressBar): what it shuffles and its percentage as it opens, then the
# percentage at each quarter, never every repaint of a long shuffle.
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

load File.join(Harness::ROOT, "games", "infinitefusion_common", "shuffle_progress.rb")

Suite.define("if shuffle progress: the bar's text and percentage as it opens, then each quarter it reaches") do
  SpeakCapture.clear
  bar = ShuffleProgressBar.new("Shuffling wild Pokémon...")
  eq "opening: what it shuffles and where it starts, queued", SpeakCapture.log, [["Shuffling wild Pokémon... 0%", false]]
  SpeakCapture.clear
  [0.1, 0.2, 0.26, 0.3, 0.49, 0.5, 0.99, 1.0].each { |p| bar.progress = p }
  eq "then only the repaints that reach a new quarter", SpeakCapture.lines, ["26%", "50%", "99%", "100%"]
end
