# Soulstones 2's multi-box picker (games/soulstones2/box_picker.rb): each paint says the focused box, what it holds
# and its set, or the set button under the cursor; and the PC says the tint the picker's search leaves.

# The picker as the game paints it: the focused box's rows (the name row's label reads "Set Box:" while a box is
# pinned), then the two set-switch buttons; rows, when given, are painted instead, as a screen in another state would.
# Its cursor starts on the first box.
class PokemonBox_Scene
  attr_accessor :box_name, :holds, :set, :rows
  def initialize; @box_name = "Caja 1"; @holds = "Holds: 4"; @set = "1 - 30"; @index = 0; end

  def pbUpdateOverlay
    if @rows
      pbDrawTextPositions(nil, @rows)
    else
      label = (@curbox.nil? || @curbox == []) ? "Box #:" : "Set Box:"
      pbDrawTextPositions(nil, [[@holds, 4, 16], ["Box Set", 4, 142], [@set, 4, 170],
                                [label, 4, 314], [@box_name, 4, 350]])
      pbDrawTextPositions(nil, [["Box 61-90", 280, 346], ["Box 31-60", 412, 346]])
    end
    :drawn
  end

  def index=(i); @index = i; end
end

class Ss2BoxPickerGdTest < PokeAccessTest
  # A box of the picker's set: its name and slots.
  Box = Struct.new(:name, :mons) do
    def length; mons.length; end
    def [](i); mons[i]; end
  end

  # A Pokemon in a box, as the picker's search tests it.
  Mon = Struct.new(:species, :types, :item, :shiny) do
    def hasItem?; !item.nil?; end
    def shiny?; shiny ? true : false; end
  end

  # A Pokemon whose types, item and shininess cannot be read.
  Unreadable = Struct.new(:species) do
    def types; raise "no data"; end
    def hasItem?; raise "no data"; end
    def shiny?; raise "no data"; end
  end

  # The box the cursor stands on in the data tests: two Pikachu, an empty slot and a shiny Charmander with an item.
  FOCUSED = Box.new("Caja 5", [Mon.new(25, [:ELECTRIC], nil, false), nil, Mon.new(4, [:FIRE], :CHARCOAL, true),
                               Mon.new(25, [:ELECTRIC], nil, false)])

  # The search the picker leaves on $PokemonStorage: by type, species, item held or shininess.
  Storage = Struct.new(:sortType, :sortSpecies, :sortItems, :sortShiny)

  # Soulstones 2's pc_details and pc_line, which add the tint its search leaves: the profile file is evaluated once,
  # binding the picker's hook to the class above, and the stock readers, the overrides listing and the profile name are
  # put back at once; with_storage puts these two in place for a test.
  TINT_READERS = begin
    party = PokeAccess::Party
    stock = [party.method(:pc_details), party.method(:pc_line)]
    overrides = PokeAccess::Hooks.overrides.length
    profiles = PokeAccess::Game.profiles.dup
    begin
      path = File.join(Harness::ROOT, "games", "soulstones2", "box_picker.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      [party.method(:pc_details), party.method(:pc_line)]
    ensure
      party.define_singleton_method(:pc_details, stock[0])
      party.define_singleton_method(:pc_line, stock[1])
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
      PokeAccess::Game.profiles.replace(profiles)
    end
  end

  test "says the focused box's name, what it holds and its set, interrupting, without the set buttons" do
    assert_equal :drawn, PokemonBox_Scene.new.pbUpdateOverlay, "the screen paints as it would"
    assert_equal [["Caja 1, Holds: 4, 1 - 30", true]], SpeakCapture.log
  end

  test "takes a cursor the screen has not set yet for the first box" do
    scene = PokemonBox_Scene.new
    scene.remove_instance_variable(:@index)
    scene.pbUpdateOverlay
    assert_equal [["Caja 1, Holds: 4, 1 - 30", true]], SpeakCapture.log
  end

  test "says the same box no more when the screen paints it again" do
    scene = PokemonBox_Scene.new
    scene.pbUpdateOverlay
    SpeakCapture.clear
    scene.pbUpdateOverlay
    assert_nothing_spoken
  end

  test "says the next box without its set, which has not changed" do
    scene = PokemonBox_Scene.new
    scene.pbUpdateOverlay
    scene.box_name = "Caja 2"
    scene.holds = "Holds: 0"
    SpeakCapture.clear
    scene.pbUpdateOverlay
    assert_equal [["Caja 2, Holds: 0", true]], SpeakCapture.log
  end

  test "says the set again on switching sets, as that is what changed" do
    scene = PokemonBox_Scene.new
    scene.pbUpdateOverlay
    scene.set = "31 - 60"
    scene.box_name = "Caja 31"
    SpeakCapture.clear
    scene.pbUpdateOverlay
    assert_equal [["Caja 31, Holds: 4, 31 - 60", true]], SpeakCapture.log
  end

  test "past the thirty boxes, says the set button under the cursor by the name painted on it" do
    { 30 => "Box 61-90", 31 => "Box 31-60" }.each do |index, button|
      SpeakCapture.clear
      scene = PokemonBox_Scene.new
      scene.index = index
      scene.pbUpdateOverlay
      assert_equal [[button, true]], SpeakCapture.log, "at #{index}"
    end
  end

  test "says a set button once while the cursor stays on it" do
    scene = PokemonBox_Scene.new
    scene.index = 31
    scene.pbUpdateOverlay
    SpeakCapture.clear
    scene.pbUpdateOverlay
    assert_nothing_spoken
  end

  test "says the other set button as the cursor moves onto it" do
    scene = PokemonBox_Scene.new
    scene.index = 31
    scene.pbUpdateOverlay
    scene.index = 30
    SpeakCapture.clear
    scene.pbUpdateOverlay
    assert_equal [["Box 61-90", true]], SpeakCapture.log
  end

  test "says nothing past the set buttons, where nothing is painted" do
    scene = PokemonBox_Scene.new
    scene.index = 32
    scene.pbUpdateOverlay
    assert_nothing_spoken
  end

  test "says nothing for a paint with fewer rows than a box's, a box pinned or not" do
    { "no box pinned" => PokemonBox_Scene.new, "a box pinned" => pinned_scene }.each do |what, scene|
      scene.rows = [["Holds: 4", 4, 16], ["Box Set", 4, 142], ["1 - 30", 4, 170], ["Caja 1", 4, 350]]
      scene.pbUpdateOverlay
      assert_nothing_spoken "with #{what}"
    end
  end

  test "reads a paint of the focused box's five rows alone" do
    scene = PokemonBox_Scene.new
    scene.rows = [["Holds: 4", 4, 16], ["Box Set", 4, 142], ["1 - 30", 4, 170], ["Box #:", 4, 314], ["Caja 1", 4, 350]]
    scene.pbUpdateOverlay
    assert_equal [["Caja 1, Holds: 4, 1 - 30", true]], SpeakCapture.log
  end

  test "with a box pinned, names the focused box from the data and says the pin the first time" do
    pinned_scene.pbUpdateOverlay
    assert_equal [["Caja 5, Holds: 4, 1 - 30, Set Box: Guarderia", true]], SpeakCapture.log
  end

  test "names the last of the thirty boxes from the data and counts its hits, as any other" do
    scene = pinned_scene
    scene.instance_variable_set(:@curset, Array.new(29) { Box.new("Otra", []) } + [Box.new("Caja 30", FOCUSED.mons)])
    scene.instance_variable_set(:@sortSpecies, 25)
    scene.index = 29
    scene.pbUpdateOverlay
    matches = PokeAccess::I18n.t(:ss2_box_matches, :n => 2)
    assert_equal [["Caja 30, Holds: 4, #{matches}, 1 - 30, Set Box: Guarderia", true]], SpeakCapture.log
  end

  test "says the pinned box once while it stays pinned" do
    scene = pinned_scene
    scene.pbUpdateOverlay
    scene.holds = "Holds: 1"
    SpeakCapture.clear
    scene.pbUpdateOverlay
    assert_equal [["Caja 5, Holds: 1", true]], SpeakCapture.log
  end

  test "with a box pinned, says nothing for a focused box the data does not hold" do
    scene = pinned_scene
    scene.instance_variable_set(:@curset, [])
    scene.pbUpdateOverlay
    assert_nothing_spoken
  end

  test "takes the screen's empty pin for none, naming the box as painted" do
    scene = pinned_scene
    scene.instance_variable_set(:@curbox, [])
    scene.pbUpdateOverlay
    assert_equal [["Guarderia, Holds: 4, 1 - 30", true]], SpeakCapture.log
  end

  test "says how many of the focused box the running search tints, from one up" do
    { [:@sortType, :FIRE] => 1, [:@sortSpecies, 25] => 2 }.each do |(ivar, value), hits|
      SpeakCapture.clear
      scene = data_scene
      scene.instance_variable_set(ivar, value)
      scene.pbUpdateOverlay
      matches = PokeAccess::I18n.t(:ss2_box_matches, :n => hits)
      assert_equal [["Caja 1, Holds: 4, #{matches}, 1 - 30", true]], SpeakCapture.log, "#{ivar} #{value.inspect}"
    end
  end

  test "says no count for a search that tints none" do
    scene = data_scene
    scene.instance_variable_set(:@sortType, :WATER)
    scene.pbUpdateOverlay
    assert_equal [["Caja 1, Holds: 4, 1 - 30", true]], SpeakCapture.log
  end

  test "counts the search's hits by type, species, item held or not, and shininess, by the screen's own tests" do
    { [:@sortType, :FIRE] => 1, [:@sortSpecies, 25] => 2, [:@sortItems, true] => 1, [:@sortItems, false] => 2,
      [:@sortShiny, true] => 1, [:@sortShiny, false] => 2 }.each do |(ivar, value), hits|
      scene = data_scene
      scene.instance_variable_set(ivar, value)
      assert_equal hits, PokeAccess::SS2BoxPicker.matches(scene), "#{ivar} #{value.inspect}"
    end
  end

  test "counts a Pokemon whose data cannot be read as of no type, holding nothing and not shiny" do
    { [:@sortType, :FIRE] => 0, [:@sortItems, true] => 0, [:@sortItems, false] => 1, [:@sortShiny, true] => 0,
      [:@sortShiny, false] => 1 }.each do |(ivar, value), hits|
      scene = PokemonBox_Scene.new
      scene.instance_variable_set(:@curset, [Box.new("Caja 9", [Unreadable.new(25)])])
      scene.instance_variable_set(ivar, value)
      assert_equal hits, PokeAccess::SS2BoxPicker.matches(scene), "#{ivar} #{value.inspect}"
    end
  end

  test "counts nothing with no search running" do
    assert_nil PokeAccess::SS2BoxPicker.matches(data_scene)
  end

  test "counts no hits where no box lies under the cursor: on a set button, or with no set held" do
    button = data_scene
    button.index = 30
    unset = PokemonBox_Scene.new
    { "a set button" => button, "no set" => unset }.each do |what, scene|
      scene.instance_variable_set(:@sortType, :FIRE)
      assert_equal 0, PokeAccess::SS2BoxPicker.matches(scene), what
    end
  end

  test "tints a PC slot by the search the picker left: red without the type, green on the species, blue on the item" do
    PokeAccess::Config.verbosity = :brief
    pikachu = slot_mon("Chispa", :PIKACHU, [:ELECTRIC], false)
    holder = slot_mon("Brasa", :CHARMANDER, [:FIRE], true)
    not_fire = PokeAccess::I18n.t(:ss2_tint_not_type, :t => PokeAccess::Data.type_name(:FIRE))
    match = PokeAccess::I18n.t(:ss2_tint_match)
    searches = { nil => [nil, nil], Storage.new => [nil, nil], Storage.new(:FIRE) => [not_fire, nil],
                 Storage.new(nil, :PIKACHU) => [match, nil], Storage.new(nil, nil, false) => [match, nil],
                 Storage.new(nil, nil, true) => [nil, match], Storage.new(nil, nil, nil, true) => [nil, nil] }
    searches.each do |storage, tints|
      with_storage(storage) do
        [pikachu, holder].zip(tints).each do |mon, tint|
          head = PokeAccess::I18n.t(:pc_slot, :name => mon.name, :level => 25)
          assert_equal [head, tint].compact.join(", "), PokeAccess::Party.pc_line(mon, ""),
                       "#{mon.name}, #{storage.inspect}"
        end
      end
    end
  end

  test "takes a stored Pokemon that cannot tell its item for one holding none" do
    PokeAccess::Config.verbosity = :brief
    mon = slot_mon("Chispa", :PIKACHU, [:ELECTRIC], false)
    def mon.hasItem?; raise "no item data"; end
    head = PokeAccess::I18n.t(:pc_slot, :name => "Chispa", :level => 25)
    assert_equal "#{head}, #{PokeAccess::I18n.t(:ss2_tint_match)}",
                 with_storage(Storage.new(nil, nil, false)) { PokeAccess::Party.pc_line(mon, "") }
  end

  test "tints no empty PC slot" do
    with_storage(Storage.new(:FIRE)) { assert_nil PokeAccess::SS2StorageTint.phrase(nil) }
  end

  test "says the tint right after the slot's name, level and place in full too" do
    pikachu = slot_mon("Chispa", :PIKACHU, [:ELECTRIC], false)
    head = "#{PokeAccess::I18n.t(:pc_slot, :name => 'Chispa', :level => 25)}, fila 1 columna 2"
    plain = with_storage(Storage.new) { PokeAccess::Party.pc_line(pikachu, ", fila 1 columna 2") }
    tinted = with_storage(Storage.new(:FIRE)) { PokeAccess::Party.pc_line(pikachu, ", fila 1 columna 2") }
    not_fire = PokeAccess::I18n.t(:ss2_tint_not_type, :t => PokeAccess::Data.type_name(:FIRE))
    assert_equal head, plain[0, head.length], "the untinted line starts with its name, level and place"
    assert_equal "#{head}, #{not_fire}#{plain[head.length..-1]}", tinted
  end

  test "says an egg's tint after it, as its line has no details" do
    egg = slot_mon("Huevo", :CHARMANDER, [:FIRE], false)
    def egg.egg?; true; end
    egg_word = PokeAccess::I18n.t(:pty_egg)
    not_electric = PokeAccess::I18n.t(:ss2_tint_not_type, :t => PokeAccess::Data.type_name(:ELECTRIC))
    assert_equal "#{egg_word}, #{not_electric}",
                 with_storage(Storage.new(:ELECTRIC)) { PokeAccess::Party.pc_line(egg, "") }
    assert_equal egg_word, with_storage(Storage.new(:FIRE)) { PokeAccess::Party.pc_line(egg, "") }, "of the type"
  end

  private

  # A picker with "Guarderia" pinned: the name row paints the pin, and the focused box is Caja 5 of the data.
  def pinned_scene
    scene = data_scene
    scene.box_name = "Guarderia"
    scene.instance_variable_set(:@curbox, Box.new("Guarderia", []))
    scene
  end

  # A picker whose set holds the focused box's data.
  def data_scene
    scene = PokemonBox_Scene.new
    scene.instance_variable_set(:@curset, [FOCUSED])
    scene
  end

  # A stored Pokemon at level 25 as the PC reads it, with its types and whether it holds an item.
  def slot_mon(name, species, types, holds)
    mon = Poke.build(:name => name, :species => species, :gender => 2)
    mon.define_singleton_method(:types) { types }
    mon.define_singleton_method(:hasItem?) { holds }
    mon
  end

  # The block's value with $PokemonStorage holding the given search and Soulstones 2's PC readers in place of the ones
  # there, all put back after.
  def with_storage(storage)
    party = PokeAccess::Party
    held = [$PokemonStorage, party.method(:pc_details), party.method(:pc_line)]
    $PokemonStorage = storage
    party.define_singleton_method(:pc_details, TINT_READERS[0])
    party.define_singleton_method(:pc_line, TINT_READERS[1])
    yield
  ensure
    if held
      $PokemonStorage = held[0]
      party.define_singleton_method(:pc_details, held[1])
      party.define_singleton_method(:pc_line, held[2])
    end
  end
end
