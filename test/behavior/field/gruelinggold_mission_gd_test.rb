# Grueling Gold's mission reminder (games/gruelinggold/mission_log.rb): each time the overlay shows, the main quest's
# current stage its window writes is said, queued and without its text codes. The stand-in below holds
# Mission_Overlay's name only while the file binds, so no other test sees it.

# The overlay in the game's shape: pbShow writes the main quest's stage description on its window, shows it and
# starts its five-step count, which it answers.
class GgMissionOverlay
  Window = Struct.new(:text, :visible)

  def initialize(stage_text)
    @stage_text = stage_text
    @sprites = { "descwindow" => Window.new("", false) }
  end

  def pbShow
    @sprites["descwindow"].text = @stage_text
    @sprites["descwindow"].visible = true
    @steps = 5
  end
end

mission_overlay_made = !Object.const_defined?(:Mission_Overlay, false)
Object.const_set(:Mission_Overlay, GgMissionOverlay) if mission_overlay_made
begin
  mission_log = File.join(Harness::ROOT, "games", "gruelinggold", "mission_log.rb")
  eval(Harness.source(mission_log), TOPLEVEL_BINDING, mission_log)
ensure
  Object.send(:remove_const, :Mission_Overlay) if mission_overlay_made
end

class GruelingGoldMissionGdTest < PokeAccessTest
  STAGE = "Head to Professor Elm's lab in New Bark Town."

  test "says the stage the reminder writes as it shows, queued" do
    GgMissionOverlay.new(STAGE).pbShow
    assert_equal [[STAGE, false]], SpeakCapture.log
  end

  test "says the stage without the window's text codes" do
    GgMissionOverlay.new("<c2=463F0000>Find the Egg</c2> in Mr. Pokemon's house.").pbShow
    assert_equal [["Find the Egg in Mr. Pokemon's house.", false]], SpeakCapture.log
  end

  test "says the stage each time the reminder shows" do
    overlay = GgMissionOverlay.new(STAGE)
    2.times { overlay.pbShow }
    assert_equal [[STAGE, false], [STAGE, false]], SpeakCapture.log
  end

  test "says nothing for a stage with no description, and the next stage it writes" do
    ["", STAGE].each { |text| GgMissionOverlay.new(text).pbShow }
    assert_equal [[STAGE, false]], SpeakCapture.log
  end

  test "the reminder keeps its own result" do
    assert_equal 5, GgMissionOverlay.new(STAGE).pbShow
  end
end
