# The Ekans snake minigame's Sitrus Berry (plugins/ekans_snake.rb, Royal): its countdown, repainted each second with a
# sound tick, is said once as the berry appears, queued behind the score, with the seconds it first paints. The
# plugin's hook is evaluated again over the stand-in below, which holds the game's name only while it binds.

# Ekans_Interface_Game#set_sitrus_timer as the game paints it: the overlay cleared, then the seconds left in its
# middle while some are left.
class EkansSitrusGame
  def set_sitrus_timer(s)
    return :cleared unless s > 0
    pbDrawTextPositions(nil, [[s.to_s, 250, 160, 0, nil, nil]])
    :ticked
  end
end

ekans = File.join(Harness::ROOT, "plugins", "ekans_snake.rb")
ekans_src = Harness.source(ekans)
sitrus = ekans_src.match(/^PokeAccess::Hooks\.after_hook\("Ekans_Interface_Game", :set_sitrus_timer.*?^end\r?\n/m)
ekans_held = Object.const_defined?(:Ekans_Interface_Game) ? Ekans_Interface_Game : nil
begin
  Object.send(:remove_const, :Ekans_Interface_Game) if ekans_held
  Object.const_set(:Ekans_Interface_Game, EkansSitrusGame)
  eval(sitrus[0], TOPLEVEL_BINDING, ekans, ekans_src[0, sitrus.begin(0)].count("\n") + 1)
ensure
  Object.send(:remove_const, :Ekans_Interface_Game)
  Object.const_set(:Ekans_Interface_Game, ekans_held) if ekans_held
end

class EkansSitrusGdTest < PokeAccessTest
  test "the berry is said once as it appears, queued, with the seconds it first paints, its clearing silent" do
    game = EkansSitrusGame.new
    [0, 6, 5, 4, 3, 2, 1, 0].each { |s| game.set_sitrus_timer(s) }
    assert_equal [["Baya Zidra: 6 segundos", false]], SpeakCapture.log
  end

  test "once a berry is eaten or runs out, the next one is said again" do
    game = EkansSitrusGame.new
    [6, 5, 0, 6, 5, 4, 3, 2, 1, 0].each { |s| game.set_sitrus_timer(s) }
    assert_equal ["Baya Zidra: 6 segundos", "Baya Zidra: 6 segundos"], SpeakCapture.lines
  end

  test "a game resumed with a berry up says it with the seconds left" do
    game = EkansSitrusGame.new
    [1, 0].each { |s| game.set_sitrus_timer(s) }
    assert_equal ["Baya Zidra: 1 segundo"], SpeakCapture.lines
  end

  test "each game starts with no berry heard" do
    EkansSitrusGame.new.set_sitrus_timer(6)
    EkansSitrusGame.new.set_sitrus_timer(6)
    assert_equal 2, SpeakCapture.lines.length
  end

  test "the countdown keeps the game's own answer" do
    assert_equal :ticked, EkansSitrusGame.new.set_sitrus_timer(4)
  end
end
