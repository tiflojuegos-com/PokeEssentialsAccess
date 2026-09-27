# Soulstones 2's hall of fame viewer on the PC opens on the summary (pbUpdatePC(true)) and Action switches between
# it and the member panel; core reads both (the engine stub's HallOfFame_Scene paints them). The stand-in adds
# pbUpdatePC as the game's runs it: the summary with fullview, else the current member.
class HallOfFame_Scene
  attr_accessor :ss2_entry, :ss2_index

  def pbUpdatePC(fullview = false)
    fullview ? writeWelcome : writePokemonData(@ss2_entry[@ss2_index], 1)
    true
  end
end
require File.expand_path("../../../games/soulstones2/hall_of_fame", File.dirname(__FILE__))

Suite.define("soulstones 2 hall of fame: every Action that switches the PC viewer says what it switched to") do
  member = Struct.new(:name, :level, :species) do
    def egg?; false; end
  end
  scene = HallOfFame_Scene.new
  scene.ss2_entry = [member.new("Chispa", 50, 25), member.new("Brasa", 40, 4)]
  scene.ss2_index = 0
  summary = /Congrats! Records Logged!/

  SpeakCapture.clear
  scene.pbUpdatePC(true)
  spoke "the viewer opens on the summary", summary
  SpeakCapture.clear
  scene.pbUpdatePC(true)
  silent "the first Action asks for the summary it already shows, which stays silent"
  scene.pbUpdatePC
  spoke "the next switches to the member panel", /Chispa Lv\. 50/
  SpeakCapture.clear
  scene.pbUpdatePC(true)
  spoke "and the next back to the summary, said again", summary
  SpeakCapture.clear
  scene.pbUpdatePC
  spoke "and to the same member, said again", /Chispa Lv\. 50/
  SpeakCapture.clear
  scene.pbUpdatePC
  silent "a repaint of the same view says nothing"
  scene.ss2_index = 1
  scene.pbUpdatePC
  spoke "moving through the team in the panel view reads each member", /Brasa Lv\. 40/
end
