# Soulstones 2's multi-box picker, a grid walked with an arrow sprite: each move's paint is captured for the box's
# name, what it holds and its set; the two set-switch buttons are read only with the cursor on one.
class PokemonBox_Scene
  attr_accessor :box_name, :holds, :set
  def initialize; @box_name = "Caja 1"; @holds = "Holds: 4"; @set = "1 - 30"; end
  def pbUpdateOverlay
    pbDrawTextPositions(nil, [[@holds, 4, 16], ["Box Set", 4, 142], [@set, 4, 170],
                              ["Box #:", 4, 314], [@box_name, 4, 350]])
    pbDrawTextPositions(nil, [["Box 61-90", 280, 346], ["Box 31-60", 412, 346]])
    :drawn
  end
  def index=(i); @index = i; end
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
  SpeakCapture.clear
  scene.pbUpdateOverlay
  silent "the second paint the screen makes as it opens says the same box no more"

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

  scene.index = 31
  SpeakCapture.clear
  scene.pbUpdateOverlay
  eq "past the thirty boxes, the set-switch button under the cursor by the name painted on it",
     SpeakCapture.lines, ["Box 31-60"]
  scene.index = 30
  SpeakCapture.clear
  scene.pbUpdateOverlay
  eq "and the other one", SpeakCapture.lines, ["Box 61-90"]
end

# With a box pinned, the name row writes the pinned box on every step and the focused one's name is not painted;
# and a search is answered by pictures and tints alone.
Suite.define("soulstones 2 box picker: a pinned box is said once, the focused box by name, and search matches") do
  t = PokeAccess::I18n
  box = Struct.new(:name, :mons) do
    def length; mons.length; end
    def [](i); mons[i]; end
  end
  mon = Struct.new(:species, :types)
  focused = box.new("Caja 5", [mon.new(25, [:ELECTRIC]), nil, mon.new(4, [:FIRE]), mon.new(25, [:ELECTRIC])])
  scene = PokemonBox_Scene.new
  scene.box_name = "Guarderia"
  scene.instance_variable_set(:@curbox, box.new("Guarderia", []))
  scene.instance_variable_set(:@curset, [focused])
  scene.instance_variable_set(:@index, 0)
  scene.instance_variable_set(:@sortSpecies, 25)
  SpeakCapture.clear
  scene.pbUpdateOverlay
  line = SpeakCapture.lines.first.to_s
  truthy "the focused box by its own name", line.start_with?("Caja 5")
  truthy "how many of it the search tints", line.include?(t.t(:ss2_box_matches, :n => 2))
  truthy "and the pinned box, the first time", line.include?("Box #: Guarderia")
  scene.holds = "Holds: 1"
  SpeakCapture.clear
  scene.pbUpdateOverlay
  falsy "not again while it stays pinned", SpeakCapture.lines.first.to_s.include?("Guarderia")
end

# The picker's search outlives it on $PokemonStorage, and the PC's box icons keep its tint (Storage System Utilities'
# PokemonBoxIcon#update): red without the searched type, green on the searched species, blue on an item held or not
# as searched; the shiny search tints nothing there.
Suite.define("soulstones 2 box picker: the PC slot says the tint the running search leaves on its icon") do
  t = PokeAccess::I18n
  saved = $PokemonStorage
  storage = Struct.new(:sortType, :sortSpecies, :sortItems, :sortShiny).new
  pk = Poke.build(:name => "Chispa", :species => :PIKACHU, :gender => 2)
  def pk.types; [:ELECTRIC]; end
  def pk.hasItem?; false; end
  egg = Poke.build(:name => "Huevo", :species => :CHARMANDER)
  def egg.types; [:FIRE]; end
  def egg.egg?; true; end
  line = lambda { |mon| PokeAccess::Party.pc_line(mon, "") }
  begin
    $PokemonStorage = storage
    plain = line.call(pk)
    falsy "no search, no tint", plain.include?(t.t(:ss2_tint_match))

    storage.sortType = :FIRE
    not_fire = t.t(:ss2_tint_not_type, :t => PokeAccess::Data.type_name(:FIRE))
    truthy "a Pokemon without the searched type is tinted red, said right after its name and level",
           line.call(pk).include?("#{PokeAccess::I18n.t(:pc_slot, :name => 'Chispa', :level => 25)}, #{not_fire}")
    falsy "one with it is left as it is", line.call(egg).include?(not_fire)

    storage.sortType = :ELECTRIC
    truthy "an egg's icon is tinted too, and said after it", line.call(egg).end_with?(", #{t.t(:ss2_tint_not_type, :t => PokeAccess::Data.type_name(:ELECTRIC))}")

    storage.sortType = nil
    storage.sortSpecies = :PIKACHU
    truthy "the searched species is tinted green", line.call(pk).include?(t.t(:ss2_tint_match))

    storage.sortSpecies = nil
    storage.sortItems = false
    truthy "the item search tints the ones as searched, here without an item", line.call(pk).include?(t.t(:ss2_tint_match))
    storage.sortItems = true
    falsy "and not the others", line.call(pk).include?(t.t(:ss2_tint_match))

    storage.sortItems = nil
    storage.sortShiny = true
    eq "the shiny search tints nothing in the PC", line.call(pk), plain

    storage.sortShiny = nil
    storage.sortType = :FIRE
    PokeAccess::Config.verbosity = :brief
    truthy "brief keeps it", line.call(pk).include?(not_fire)
  ensure
    PokeAccess::Config.verbosity = :full
    $PokemonStorage = saved
  end
end
