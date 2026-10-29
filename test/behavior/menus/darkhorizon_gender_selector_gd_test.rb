# Dark Horizon's edited BW Gender Selector (games/darkhorizon/gender_selector.rb): pbStartScene paints the title over the
# two portraits, then the selection loop (pbUpdate) lights one by @select, the boy first; the title and the controls are
# said as it opens, then each portrait as it lights, and the lit one is kept on the info key until the scene ends.

# The scene, its loop cut down to the frames a test gives it: each frame sets @select (as selectBoy and selectGirl do
# once their animation ends) and runs the frame pollers. The class is the one Royal's stand-in reopens, whose select*
# methods this test leaves alone.
class GenderSelectorScene
  def initialize(frames = [], title = [["Choose a Player", 176, 21, :left]])
    @frames = frames
    @title = title
    @select = -1
  end

  def pbStartScene
    pbDrawTextPositions(nil, @title) unless @title.empty?
    :started
  end

  def pbUpdate
    @frames.each do |sel|
      @select = sel
      PokeAccess::Frame.run_pollers
    end
    :finished
  end

  def pbEndScene
    :ended
  end
end

# The profile's reader, which the harness does not load, evaluated once over the stand-in.
gender_path = File.join(Harness::ROOT, "games", "darkhorizon", "gender_selector.rb")
eval(Harness.source(gender_path), TOPLEVEL_BINDING, gender_path)

class DarkhorizonGenderSelectorGdTest < PokeAccessTest
  T = PokeAccess::I18n

  test "says the painted title as the scene opens, queued, with the controls while key hints are said" do
    said = vb_levels do
      SpeakCapture.clear
      GenderSelectorScene.new.pbStartScene
      SpeakCapture.log.dup
    end
    hinted = "Choose a Player. #{T.t(:gsel_help_hint)}"
    assert_equal [[["Choose a Player", false]], [[hinted, false]], [[hinted, false]]], said, "at brief, medium, full"
  end

  test "a copy that paints no title is named by the mod's own words" do
    GenderSelectorScene.new([], []).pbStartScene
    assert_equal ["#{T.t(:gsel_help)}. #{T.t(:gsel_help_hint)}"], SpeakCapture.lines
  end

  test "says the boy the loop lights first, queued behind the title, then each portrait it moves to, cutting in" do
    GenderSelectorScene.new([-1, 0, 0, 1, 1, 0]).pbUpdate
    assert_equal [[T.t(:gsel_boy), false], [T.t(:gsel_girl), true], [T.t(:gsel_boy), true]], SpeakCapture.log
  end

  test "says nothing while no portrait is lit" do
    GenderSelectorScene.new([-1, -1]).pbUpdate
    assert_nothing_spoken
  end

  test "keeps the lit portrait on the info key until the scene ends" do
    scene = GenderSelectorScene.new([0, 1])
    scene.pbUpdate
    lit = PokeAccess::Info.info_text
    scene.pbEndScene
    assert_equal [T.t(:gsel_girl), nil], [lit, PokeAccess::Info.info_text]
  end

  test "reads the portraits again, the first queued, each time the selector opens" do
    2.times { GenderSelectorScene.new([0]).pbUpdate }
    assert_equal [[T.t(:gsel_boy), false]] * 2, SpeakCapture.log
  end

  test "hands back what the scene's own methods answer" do
    scene = GenderSelectorScene.new([0])
    assert_equal [:started, :finished, :ended], [scene.pbStartScene, scene.pbUpdate, scene.pbEndScene]
  end
end
