# The two modal windows this game builds by hand instead of using the message system: the tutorial popups
# and the Achievement Points scoreboard after a boss. Both take the text as their first argument and then
# block until the player dismisses the window, which is why the reader hangs off the call rather than the
# return. The stand-ins are the game's own signatures, second argument and all: the scoreboard is called as
# "@scene.pbBottomRightWindow(text)" with the scene left out.
def pbTutorialWindow(text, scene = nil); [text, scene]; end
def pbBottomRightWindow(text, scene = nil); [text, scene]; end

require File.expand_path("../../../games/soulstones2/notices", File.dirname(__FILE__))

Suite.define("soulstones 2: the tutorial popups and the boss scoreboard are read, markup and all removed") do
  SpeakCapture.clear
  pbTutorialWindow("Select areas will have a Raid Den where you can confront a boss-level Pokemon.")
  spoke "a tutorial the game shows once ever is read", /Raid Den/

  SpeakCapture.clear
  pbBottomRightWindow("<b>A boss was defeated!</b>\nBattle style points:<r>+3\r\nDifficulty mode points:<r>+4\r\n<b>Total AP earned:<r>7</b>")
  line = SpeakCapture.lines.join(" ")
  match "the scoreboard names what was scored", line, /Battle style points/
  match "with the number beside it", line, /\+3/
  match "and the total", line, /Total AP earned/
  truthy "the formatting tags never reach the voice", !line.include?("<b>") && !line.include?("<r>")
  truthy "and neither do the line breaks", !line.include?("\r") && !line.include?("\n")

  SpeakCapture.clear
  pbBottomRightWindow("")
  silent "an empty window says nothing"
end
