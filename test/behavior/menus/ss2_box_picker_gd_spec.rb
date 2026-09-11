# The multi-box picker: a 6-wide grid of thirty boxes walked with an arrow SPRITE and nothing else. No
# command window, no message, no text tied to the cursor -- the whole screen is a picture, and choosing
# where to put a pokemon meant counting arrow moves.
#
# What it does paint it paints on every move, so the line is CAPTURED from that draw: the box's own name
# (the player's), how many it holds, and the set of thirty. The two set-switch buttons at the bottom are a
# second batch that does not move with the cursor, and reading them would repeat three words on every step.
class PokemonBox_Scene
  attr_accessor :box_name, :holds, :set
  def initialize; @box_name = "Caja 1"; @holds = "Holds: 4"; @set = "1 - 30"; end
  def pbUpdateOverlay
    pbDrawTextPositions(nil, [[@holds, 4, 16], ["Box Set", 4, 142], [@set, 4, 170],
                              ["Box #:", 4, 314], [@box_name, 4, 350]])
    pbDrawTextPositions(nil, [["Box 61-90", 280, 346], ["Box 31-60", 412, 346]])
    :drawn
  end
end
require File.expand_path("../../../games/soulstones2/box_picker", File.dirname(__FILE__))

Suite.define("soulstones 2 box picker: the focused box says its name and what it holds, once each") do
  scene = PokemonBox_Scene.new

  SpeakCapture.clear
  scene.pbUpdateOverlay
  eq "the first box read says its name, what it holds and which set it is in",
     SpeakCapture.lines, ["Caja 1, Holds: 4, 1 - 30"]
  falsy "and not the two set buttons, which do not move with the cursor",
        SpeakCapture.lines.first.include?("Box 61-90")

  scene.box_name = "Caja 2"
  scene.holds = "Holds: 0"
  SpeakCapture.clear
  scene.pbUpdateOverlay
  eq "moving to the next box says the new one, without repeating the set",
     SpeakCapture.lines, ["Caja 2, Holds: 0"]

  SpeakCapture.clear
  scene.pbUpdateOverlay
  silent "a repaint that changed nothing says nothing"

  scene.set = "31 - 60"
  scene.box_name = "Caja 31"
  SpeakCapture.clear
  scene.pbUpdateOverlay
  eq "and switching sets says which set, because that is what just changed",
     SpeakCapture.lines, ["Caja 31, Holds: 0, 31 - 60"]
end
