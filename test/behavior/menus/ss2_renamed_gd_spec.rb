# Soulstones 2's MoveRemember_Scene, the move relearner under another name, method for method: read by the same
# reader, its list claimed, and the questions in its own window read.
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
class Original_PokemonParty_Scene
  def pbSetHelpText(text); text; end
  def pbDisplay(text); text; end
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

  SpeakCapture.clear
  scene.pbConfirm("Teach Thunderbolt?")
  spoke "the question the screen asks in its own window is read", /Teach Thunderbolt/
end

# The Guardian's trial picks its team on a renamed party screen: its help line and the messages naming a broken rule
# go through the copy's own methods, which the profile hooks.
Suite.define("soulstones 2: the Guardian's trial party says its help line and its rule messages") do
  scene = Original_PokemonParty_Scene.new
  scene.pbSetHelpText("Choose 3 Pokemon.")
  eq "the help line is read", SpeakCapture.lines, ["Choose 3 Pokemon."]
  SpeakCapture.clear
  scene.pbDisplay("No two Pokemon can have the same species.")
  spoke "and so is the rule a pick breaks", /same species/
end
