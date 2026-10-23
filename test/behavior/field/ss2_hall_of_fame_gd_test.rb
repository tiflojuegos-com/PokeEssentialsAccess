# Soulstones 2's hall of fame viewer on the PC (games/soulstones2/hall_of_fame.rb): each Action reads the view it lands
# on, summary or member panel, even one it showed before; the view on show asked for again says nothing.

# The viewer as the game runs it: pbUpdatePC paints the summary with fullview, else the member at ss2_index; the
# painting itself (writeWelcome, writePokemonData) is the engine stub's.
class HallOfFame_Scene
  attr_accessor :ss2_entry, :ss2_index

  def pbUpdatePC(fullview = false)
    fullview ? writeWelcome : writePokemonData(@ss2_entry[@ss2_index], 1)
    true
  end
end
ss2_hall_of_fame_path = File.join(Harness::ROOT, "games", "soulstones2", "hall_of_fame.rb")
eval(Harness.source(ss2_hall_of_fame_path), TOPLEVEL_BINDING, ss2_hall_of_fame_path)

class Ss2HallOfFameGdTest < PokeAccessTest
  SUMMARY = "Congrats! Records Logged!"
  Member = Struct.new(:name, :level, :species)

  test "opens on the summary, queued, and each Action reads the view it switches to, even one it showed before" do
    scene = viewer
    scene.pbUpdatePC(true)
    [false, true, false].each { |fullview| scene.pbUpdatePC(fullview) }
    assert_equal [[SUMMARY, false], [panel("Chispa", 50), true], [SUMMARY, false], [panel("Chispa", 50), true]],
                 SpeakCapture.log
  end

  test "the view on show asked for again says nothing" do
    { "the summary" => true, "the member panel" => false }.each do |what, fullview|
      scene = viewer
      scene.pbUpdatePC(fullview)
      SpeakCapture.clear
      scene.pbUpdatePC(fullview)
      assert_nothing_spoken what
    end
  end

  test "moving through the team on the panel reads each member" do
    scene = viewer
    scene.pbUpdatePC(false)
    scene.ss2_index = 1
    scene.pbUpdatePC(false)
    assert_equal [[panel("Chispa", 50), true], [panel("Brasa", 40), true]], SpeakCapture.log
  end

  private

  # A fresh viewer on a two-member entry, the first member selected.
  def viewer
    scene = HallOfFame_Scene.new
    scene.ss2_entry = [Member.new("Chispa", 50, 25), Member.new("Brasa", 40, 4)]
    scene.ss2_index = 0
    scene
  end

  # A member panel as the stub paints it: its record number, then the member's name and level.
  def panel(name, level)
    "No. 025, #{name} Lv. #{level}"
  end
end
