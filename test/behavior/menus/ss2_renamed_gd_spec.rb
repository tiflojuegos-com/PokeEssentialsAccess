# A screen the game replaced with a copy under a DIFFERENT NAME. MoveRemember_Scene is the move relearner,
# method for method -- pbStartScene, pbDrawMoveList and the same @sprites["commands"] window core reads --
# so it was silent for one reason only: nobody had bound those two hooks to that name. The list is a command
# window nobody had dedicated, and the move's own data is drawn, not written.
class MoveRemember_Scene
  attr_reader :sprites
  def initialize(pokemon, moves, index = 0)
    @pokemon = pokemon
    @moves = moves
    win = Object.new
    win.instance_variable_set(:@i, index)
    def win.index; @i; end
    def win.index=(v); @i = v; end
    @sprites = { "commands" => win }
  end
  def focus=(i); @sprites["commands"].index = i; end
  def pbStartScene(_pokemon, _moves); @sprites; end
  def pbDrawMoveList; :drawn; end
  def pbConfirm(msg); msg; end
end
require File.expand_path("../../../games/soulstones2/renamed_screens", File.dirname(__FILE__))

Suite.define("soulstones 2: the renamed move relearner is read by the same reader as the vanilla one") do
  pk = Poke.build(:name => "Chispa")
  scene = MoveRemember_Scene.new(pk, [1, 2])

  scene.pbStartScene(pk, [1, 2])
  truthy "opening the screen marks its list as read by this screen and no other",
         PokeAccess.ivar(scene.sprites["commands"], :@access_dedicated)

  SpeakCapture.clear
  scene.pbDrawMoveList
  first = SpeakCapture.lines.join(" ")
  truthy "and redrawing says the focused move with its data", !first.strip.empty?

  scene.focus = 1
  SpeakCapture.clear
  scene.pbDrawMoveList
  truthy "moving down says the other one", SpeakCapture.lines.join(" ") != first

  # Its questions go to its own message window, the way the vanilla relearner's do; the vanilla names are in
  # core's message net and this one was not, so "Teach Thunderbolt?" went unread over a spoken yes/no.
  SpeakCapture.clear
  scene.pbConfirm("Teach Thunderbolt?")
  spoke "the question the screen asks in its own window is read", /Teach Thunderbolt/
end
