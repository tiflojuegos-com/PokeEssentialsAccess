# Infinite Fusion Hoenn's Pokeblock kit (games/infinitefusion_hoenn/pokeblocks.rb): the kit menu, the berry picker and
# its chosen berries, the case's rows and the condition screen with what a block raised, following the game's settings.

# Hoenn's Pokeblock settings: the bag pocket the berries are kept in; the simplified blending and the no-sheen switch
# are unset (off) unless a test sets them.
module PokeblockSettings
  BERRY_POCKET_OF_BAG = 5
end

# The kit menu, reduced to its loop: each frame focuses the next command of path.
class PokeblockKit_Scene
  def initialize(commands, path); @commands = commands; @path = path; @index = 0; end
  def pbScene; @path.each { |i| @index = i; Input.update }; end
end

# The blender's berry picker: the bag's berry pocket filtered into @filterlist, the close row after it, the berry
# focused in item and the blender's scene holding the berries chosen so far.
class Window_MultiBerrySelection < Window_DrawableCommand
  attr_accessor :item
  def initialize(bag, filterlist, scene, adapter = nil)
    super([])
    @bag = bag
    @filterlist = filterlist
    @scene = scene
    @adapter = adapter
  end
  def itemCount; @filterlist.length + 1; end
end

# The blender's scene: the berries chosen show only as icons, and pbRefresh follows each choice.
class MultiBerrySelection_Scene
  attr_accessor :selectedBerries
  def initialize; @selectedBerries = []; end
  def pbRefresh; end
end

# The Pokeblock case: its list window (the blocks in @list, the close row after them) and its closing.
class Window_PokeblockCase < Window_DrawableCommand
  def initialize(blocks); super([]); @list = blocks; end
end

class PokeblockCase_Scene
  def pbEndScene; end
end

# The condition screen, reduced to what the profile hooks: it draws the member at @index, moves to another, and feeds
# the one shown a block whose gains raise its conditions before the bars move.
class PokeblockCondition_Scene
  def initialize(party); @party = party; @index = 0; end
  def pbDrawPokemonInfo; :drawn; end
  def move(index); @index = index; pbDrawPokemonInfo; end
  def pbAtePokeblock(gains); gains.each { |k, v| @party[@index][k] += v }; pbUpdateConditionBars; :ate; end
  def pbUpdateConditionBars; end
end

class IfhPokeblocksGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "pokeblocks.rb")
  # A Pokeblock as the case keeps it: its flavours (spicy, dry, sweet, bitter, sour) and its feel (smoothness).
  Block = Struct.new(:name, :level, :flavor, :smoothness)
  Nature = Struct.new(:name)
  # A party member as the condition screen reads it: sex, level, nature and its six conditions.
  Mon = Struct.new(:name, :gender, :level, :nature, :cool, :beauty, :cute, :smart, :tough, :sheen, :shiny) do
    def shiny?; shiny ? true : false; end
    def hp; 20; end
    def totalhp; 20; end
    def item; nil; end
    def status; 0; end
  end
  # A party member the game gives nothing the screen reads but its name.
  Blank = Struct.new(:name)
  # The bag as the picker reads it: its pockets, each a list of [item, quantity].
  Bag = Struct.new(:pockets)
  # The bag's display names, which the picker asks before the item's own.
  Adapter = Struct.new(:names) do
    def getDisplayName(item); names[item]; end
  end
  # A berry chosen for the blender, the same berry as the item data of its id.
  Chosen = Struct.new(:id) do
    def ==(other); other.respond_to?(:id) && other.id == id; end
  end
  # A berry's block colour, as GameData::BerryData keeps it.
  BerryColour = Struct.new(:block_color_name)

  # Evaluates the profile file once, as boot does, its hooks bound to the stand-ins above.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  test "a case row says the block, then its level, the flavours its panel marks and its feel" do
    assert_equal red_row, case_row(red_block)
  end

  test "a case row at brief says the block's name alone, from medium all of it" do
    assert_equal ["Red Pokeblock", red_row, red_row], vb_levels { case_row(red_block) }
  end

  test "the info key keeps a block's whole row at any level" do
    PokeAccess::Config.verbosity = :brief
    case_row(red_block)
    assert_equal red_row, PokeAccess::Info.info_text
  end

  test "a block with no flavour marked says none" do
    { "every flavour at zero" => [0, 0, 0, 0, 0], "no flavour data" => nil }.each do |label, flavor|
      plain = Block.new("Plain Pokeblock", 3, flavor, 10)
      assert_equal "Plain Pokeblock, #{t(:dbk_level, :n => 3)}, #{t(:pbk_feel, :n => 10)}", case_row(plain), label
    end
  end

  test "the close row says so and takes the block off the info key, for T and Ctrl+T alike" do
    win = Window_PokeblockCase.new([red_block])
    PokeAccess::Menus.focused_text(win)
    win.index = 1
    said = PokeAccess::Menus.focused_text(win)
    assert_equal ["CLOSE CASE", nil, nil], [said, PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "closing the case takes its block off the info key" do
    case_row(red_block)
    PokeblockCase_Scene.new.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "with the simplified blending a case row has no level nor feel" do
    row = with_settings(:SIMPLIFIED_BERRY_BLENDING => true) { case_row(red_block) }
    assert_equal "Red Pokeblock, #{red_flavours}", row
  end

  test "without sheen a case row has no feel but keeps its level" do
    row = with_settings(:DONT_USE_SHEEN => true) { case_row(red_block) }
    assert_equal "Red Pokeblock, #{t(:dbk_level, :n => 12)}, #{red_flavours}", row
  end

  test "the condition screen says the Pokemon with its sign, level and nature, then every condition, queued" do
    scene = PokeblockCondition_Scene.new([zigzagoon])
    scene.pbDrawPokemonInfo
    line = "Zigzagoon ♂, #{t(:dbk_level, :n => 5)}, #{t(:sm_nature, :n => 'Firme')}, #{conditions}"
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "the condition screen at the reading's levels: the name and the conditions, then the level" do
    scene = PokeblockCondition_Scene.new([zigzagoon])
    rows = vb_levels do
      PokeAccess::Cursor.reset(scene, :pbk_cond)
      SpeakCapture.clear
      scene.pbDrawPokemonInfo
      SpeakCapture.last
    end
    assert_equal "Zigzagoon, #{conditions}", rows[0], "brief: the conditions stand for the hit points here"
    assert_equal "Zigzagoon, #{t(:dbk_level, :n => 5)}, #{conditions}", rows[1], "medium: and the level"
  end

  test "the info key says the Pokemon shown, and Ctrl+T its whole row, at any level" do
    mon = zigzagoon
    PokeAccess::Config.verbosity = :brief
    PokeblockCondition_Scene.new([mon]).pbDrawPokemonInfo
    whole = "Zigzagoon ♂, #{t(:dbk_level, :n => 5)}, #{t(:sm_nature, :n => 'Firme')}, #{conditions}"
    assert_equal [PokeAccess::Info.pokemon_info(mon), whole], [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "drawing and feeding keep the screen's own returns" do
    scene = PokeblockCondition_Scene.new([zigzagoon])
    assert_equal [:drawn, :ate], [scene.pbDrawPokemonInfo, scene.pbAtePokeblock(:cool => 20)]
  end

  test "a shiny Pokemon is marked in full" do
    mon = zigzagoon
    mon.shiny = true
    PokeblockCondition_Scene.new([mon]).pbDrawPokemonInfo
    line = "Zigzagoon ♂, #{t(:pk_shiny)}, #{t(:dbk_level, :n => 5)}, #{t(:sm_nature, :n => 'Firme')}, #{conditions}"
    assert_equal [line], SpeakCapture.lines
  end

  test "the next Pokemon interrupts, with no sign for a genderless one" do
    scene = PokeblockCondition_Scene.new([zigzagoon, wurmple])
    scene.pbDrawPokemonInfo
    SpeakCapture.clear
    scene.move(1)
    line = "Wurmple, #{t(:dbk_level, :n => 3)}, #{t(:sm_nature, :n => 'Seria')}, #{zero_conditions}"
    assert_equal [[line, true]], SpeakCapture.log
  end

  test "with the simplified blending the conditions have no sheen" do
    scene = PokeblockCondition_Scene.new([zigzagoon])
    with_settings(:SIMPLIFIED_BERRY_BLENDING => true) { scene.pbDrawPokemonInfo }
    line = "Zigzagoon ♂, #{t(:dbk_level, :n => 5)}, #{t(:sm_nature, :n => 'Firme')}, #{conditions(false)}"
    assert_equal [line], SpeakCapture.lines
  end

  test "the same member drawn again is not said again" do
    scene = PokeblockCondition_Scene.new([zigzagoon])
    scene.pbDrawPokemonInfo
    SpeakCapture.clear
    scene.pbDrawPokemonInfo
    assert_nothing_spoken
  end

  test "a second member that reads like the first is said all the same" do
    alike = Mon.new("Zigzagoon", 0, 5, Nature.new("Firme"), 0, 0, 0, 0, 0, 0)
    scene = PokeblockCondition_Scene.new([alike, alike.dup])
    scene.pbDrawPokemonInfo
    SpeakCapture.clear
    scene.move(1)
    assert_equal ["Zigzagoon ♂, #{t(:dbk_level, :n => 5)}, #{t(:sm_nature, :n => 'Firme')}, #{zero_conditions}"],
                 SpeakCapture.lines
  end

  test "a screen with no member to show says nothing" do
    [[], nil].each do |party|
      PokeblockCondition_Scene.new(party).pbDrawPokemonInfo
      assert_nothing_spoken party.inspect
    end
  end

  test "a member the game gives nothing but a name is not said, the screen going on" do
    assert_equal :drawn, PokeblockCondition_Scene.new([Blank.new("Egg")]).pbDrawPokemonInfo
    assert_nothing_spoken
  end

  test "feeding says the conditions that rose with where they are now, queued" do
    scene = PokeblockCondition_Scene.new([zigzagoon])
    scene.pbDrawPokemonInfo
    SpeakCapture.clear
    scene.pbAtePokeblock(:cool => 20, :cute => 5, :sheen => 3)
    rose = "#{t(:cnd_cool)} 30, #{t(:cnd_cute)} 5, #{t(:cnd_sheen)} 33"
    assert_equal [[t(:pbk_rose, :list => rose), false]], SpeakCapture.log
  end

  test "feeding that raises nothing says nothing" do
    scene = PokeblockCondition_Scene.new([zigzagoon])
    scene.pbDrawPokemonInfo
    SpeakCapture.clear
    scene.pbAtePokeblock({})
    assert_nothing_spoken
  end

  test "feeding with no member shown says nothing" do
    PokeblockCondition_Scene.new([]).pbAtePokeblock({})
    assert_nothing_spoken
  end

  test "feeding a member the game gives nothing but a name says nothing, the meal going on" do
    assert_equal :ate, PokeblockCondition_Scene.new([Blank.new("Egg")]).pbAtePokeblock({})
    assert_nothing_spoken
  end

  test "a berry row says the berry and how many are left, less those already thrown in" do
    scene = MultiBerrySelection_Scene.new
    scene.selectedBerries = [Chosen.new(:CHERIBERRY)]
    win = berry_picker(scene, Adapter.new({ :CHERIBERRY => "Cheri Berry" }))
    assert_equal "Cheri Berry: 2", PokeAccess::Menus.focused_text(win)
  end

  test "a picker whose scene keeps no chosen berries counts every berry in stock" do
    win = berry_picker(nil, Adapter.new({ :CHERIBERRY => "Cheri Berry" }))
    assert_equal "Cheri Berry: 3", PokeAccess::Menus.focused_text(win)
  end

  test "without the bag's display name a berry row takes the item's own" do
    win = berry_picker(MultiBerrySelection_Scene.new, nil)
    assert_equal "#{GameData::Item.get(:CHERIBERRY).name}: 3", PokeAccess::Menus.focused_text(win)
  end

  test "a berry the game's item data does not know reads by its id" do
    win = berry_picker(MultiBerrySelection_Scene.new, nil)
    win.index = 1
    win.item = :PECHABERRY
    assert_equal "PECHABERRY: 1", with_unknown_item(:PECHABERRY) { PokeAccess::Menus.focused_text(win) }
  end

  test "a row past the picker's list reads nothing" do
    win = berry_picker(MultiBerrySelection_Scene.new, nil)
    win.index = 3
    assert_nil PokeAccess::Menus.focused_text(win)
  end

  test "the focused berry's description and its block's colour go to the info key" do
    win = berry_picker(MultiBerrySelection_Scene.new, nil)
    with_berry_colours(:CHERIBERRY => "Rojo") { PokeAccess::Menus.focused_text(win) }
    assert_equal "#{GameData::Item.get(:CHERIBERRY).description} Rojo", PokeAccess::Info.info_text
  end

  test "a berry with neither a description nor a colour leaves nothing on the info key" do
    win = berry_picker(MultiBerrySelection_Scene.new, nil)
    PokeAccess::Menus.focused_text(win)
    win.index = 1
    win.item = :PECHABERRY
    with_berry_colours({}) { with_unknown_item(:PECHABERRY) { PokeAccess::Menus.focused_text(win) } }
    assert_nil PokeAccess::Info.info_text
  end

  test "the berry picker's close row says so and leaves the info key empty" do
    win = berry_picker(MultiBerrySelection_Scene.new, nil)
    PokeAccess::Menus.focused_text(win)
    win.index = 2
    win.item = nil
    assert_equal ["CLOSE BAG", nil], [PokeAccess::Menus.focused_text(win), PokeAccess::Info.info_text]
  end

  test "a translated build reads the picker's and the case's close rows in its own words" do
    picker = berry_picker(MultiBerrySelection_Scene.new, nil)
    picker.index = 2
    picker.item = nil
    case_list = Window_PokeblockCase.new([red_block])
    case_list.index = 1
    said = with_intl("CLOSE BAG" => "CERRAR BOLSA", "CLOSE CASE" => "CERRAR ESTUCHE") do
      [PokeAccess::Menus.focused_text(picker), PokeAccess::Menus.focused_text(case_list)]
    end
    assert_equal ["CERRAR BOLSA", "CERRAR ESTUCHE"], said
  end

  test "each berry chosen for the blender is said with how many of four, queued" do
    scene = MultiBerrySelection_Scene.new
    [[Chosen.new(:CHERIBERRY)], [Chosen.new(:CHERIBERRY), Chosen.new(:PECHABERRY)]].each do |chosen|
      scene.selectedBerries = chosen
      scene.pbRefresh
    end
    assert_equal [[t(:pbk_selected, :n => 1, :tot => 4), false], [t(:pbk_selected, :n => 2, :tot => 4), false]],
                 SpeakCapture.log
  end

  test "a refresh with no berry chosen yet says nothing" do
    MultiBerrySelection_Scene.new.pbRefresh
    assert_nothing_spoken
  end

  test "a refresh that chose no new berry says nothing" do
    scene = MultiBerrySelection_Scene.new
    scene.selectedBerries = [Chosen.new(:CHERIBERRY)]
    scene.pbRefresh
    SpeakCapture.clear
    scene.pbRefresh
    assert_nothing_spoken
  end

  test "the kit menu says each command the cursor reaches, the first queued" do
    PokeblockKit_Scene.new(["Blend", "Case", "Exit"], [0, 1, 1, 2]).pbScene
    assert_equal [["Blend", false], ["Case", true], ["Exit", true]], SpeakCapture.log
  end

  test "the kit menu says nothing while no command is focused" do
    PokeblockKit_Scene.new(["Blend", "Case", "Exit"], [5]).pbScene
    PokeblockKit_Scene.new(nil, [0]).pbScene
    assert_nothing_spoken
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # A spicy and sour block of level 12 and feel 20.
  def red_block
    Block.new("Red Pokeblock", 12, [3, 0, 0, 0, 1], 20)
  end

  # The flavours the red block's panel marks.
  def red_flavours
    t(:pbk_flavors, :list => "#{t(:bdx_fl_spicy)}, #{t(:bdx_fl_sour)}")
  end

  # The red block's case row whole: its name, level, flavours and feel.
  def red_row
    "Red Pokeblock, #{t(:dbk_level, :n => 12)}, #{red_flavours}, #{t(:pbk_feel, :n => 20)}"
  end

  # The case's first row as its window reads it.
  def case_row(block)
    PokeAccess::Menus.focused_text(Window_PokeblockCase.new([block]))
  end

  # A male Zigzagoon of level 5, its beauty at the maximum.
  def zigzagoon
    Mon.new("Zigzagoon", 0, 5, Nature.new("Firme"), 10, 255, 0, 0, 0, 30)
  end

  # A genderless Wurmple of level 3, every condition at zero.
  def wurmple
    Mon.new("Wurmple", 2, 3, Nature.new("Seria"), 0, 0, 0, 0, 0, 0)
  end

  # Zigzagoon's conditions as the graph lists them, its full beauty flagged as the max icon is, and its sheen unless
  # the game leaves sheen out.
  def conditions(sheen = true)
    list = ["#{t(:cnd_cool)} 10", "#{t(:cnd_beauty)} 255 #{t(:cnd_max)}", "#{t(:cnd_cute)} 0", "#{t(:cnd_smart)} 0",
            "#{t(:cnd_tough)} 0"]
    list.push("#{t(:cnd_sheen)} 30") if sheen
    t(:pbk_conditions, :list => list.join(", "))
  end

  # The conditions of a Pokemon with every one at zero, sheen included.
  def zero_conditions
    list = [:cnd_cool, :cnd_beauty, :cnd_cute, :cnd_smart, :cnd_tough, :cnd_sheen].map { |k| "#{t(k)} 0" }
    t(:pbk_conditions, :list => list.join(", "))
  end

  # The blender's picker focused on the first of its berries (three Cheri and one Pecha in the berry pocket), with
  # scene choosing and adapter naming them.
  def berry_picker(scene, adapter)
    bag = Bag.new({ PokeblockSettings::BERRY_POCKET_OF_BAG => [[:CHERIBERRY, 3], [:PECHABERRY, 1]] })
    win = Window_MultiBerrySelection.new(bag, [0, 1], scene, adapter)
    win.item = :CHERIBERRY
    win
  end

  # Runs the block with the game's Pokeblock settings set as given, unset again afterwards.
  def with_settings(values)
    values.each { |name, v| PokeblockSettings.const_set(name, v) }
    yield
  ensure
    values.each_key do |name|
      PokeblockSettings.send(:remove_const, name) if PokeblockSettings.const_defined?(name, false)
    end
  end

  # Runs the block with GameData::BerryData giving each berry's block colour, whatever stood there put back afterwards.
  def with_berry_colours(colours)
    held = GameData.const_defined?(:BerryData, false) ? GameData::BerryData : nil
    GameData.send(:remove_const, :BerryData) if held
    data = Module.new
    data.define_singleton_method(:get) { |id| BerryColour.new(colours[id]) }
    GameData.const_set(:BerryData, data)
    yield
  ensure
    GameData.send(:remove_const, :BerryData) if GameData.const_defined?(:BerryData, false)
    GameData.const_set(:BerryData, held) if held
  end

  # Runs the block with GameData::Item.get raising for id, as the game's data does for an item it does not know, the
  # stub's own get put back afterwards.
  def with_unknown_item(id)
    meta = GameData::Item.singleton_class
    meta.send(:alias_method, :pa_test_get, :get)
    meta.send(:define_method, :get) { |i| i == id ? raise(ArgumentError, "unknown item #{i}") : pa_test_get(i) }
    yield
  ensure
    meta.send(:alias_method, :get, :pa_test_get)
    meta.send(:remove_method, :pa_test_get)
  end
end
