# TDW's selector of several berries (plugins/berrydex.rb, Royal and Hero Legacy): each row at the bag's level with what it
# leaves on the info key, in every mode of its label column, and the berries as they are chosen.

# The list: rows of the bag's berry pocket through @filterlist, and the scene that keeps the berries chosen, how many
# it takes (@count) and the label column's mode (@label); past the rows, the close row.
class Window_ChooseBerryMultiple
  attr_accessor :index
  def initialize(bag, filter, scene); @bag = bag; @filterlist = filter; @scene = scene; @index = 0; end
end

# The screen: drawSelectedBerries puts the chosen berries' icons in their circles.
class ChooseBerryMultiple_Scene
  attr_accessor :selectedBerries

  def initialize(count)
    @count = count
    @selectedBerries = []
  end

  def drawSelectedBerries; end
end

begin
  path = File.join(Harness::ROOT, "plugins", "berrydex.rb")
  src = Harness.source(path)
  part = src[/^PokeAccess::Hooks\.after_hook\("ChooseBerryMultiple_Scene".*?^end\r?\n/m]
  eval(part, TOPLEVEL_BINDING, path, src[0, src.index(part)].count("\n") + 1)
end

class BerrydexMultiGdTest < PokeAccessTest
  I18n = PokeAccess::I18n
  # A berry as the picker's data keeps it.
  Berry = Struct.new(:flavor, :firmness, :size, :color)
  # A berry already chosen: the same berry as the bag's item of its id.
  Chosen = Struct.new(:id, :name) do
    def ==(other); other.respond_to?(:id) && other.id == id; end
  end
  # The picker's scene: the berries chosen so far.
  Picker = Struct.new(:selectedBerries)
  CHERI = Berry.new({ "Picante" => 10, "Seco" => 5 }, "Blanda", 2.0, :RED)

  test "reads a berry at the bag's level: how many are left, then its label and how many are chosen from medium" do
    with_berry_data(:CHERIBERRY => CHERI) do
      chosen = I18n.t(:bdx_chosen, :n => 0, :tot => 6)
      assert_equal ["ItemCHERIBERRY, 3", "ItemCHERIBERRY, 3, Picante, #{chosen}", "ItemCHERIBERRY, 3, Picante, #{chosen}"],
                   vb_levels { PokeAccess::Menus.focused_text(berry_picker([:CHERIBERRY, 3], :Flavor, [])) }
    end
  end

  test "counts down the berries of the row already chosen" do
    with_berry_data(:CHERIBERRY => CHERI) do
      picker = berry_picker([:CHERIBERRY, 3], :Flavor, [Chosen.new(:CHERIBERRY), Chosen.new(:ORANBERRY)])
      assert_equal "ItemCHERIBERRY, 2, Picante, #{I18n.t(:bdx_chosen, :n => 2, :tot => 6)}",
                   PokeAccess::Menus.focused_text(picker)
    end
  end

  test "reads the label column the picker shows, in each of its modes" do
    with_berry_data(:CHERIBERRY => CHERI) do
      chosen = I18n.t(:bdx_chosen, :n => 0, :tot => 6)
      { :Flavor => "Picante", :Color => "Rojo", :Firm => "Blanda", :Firmness => "Blanda", :Size => "2.0 cm",
        :Type => "TypeFIRE", :TypeText => "TypeFIRE", :TypeIcon => "TypeFIRE" }.each do |mode, label|
        assert_equal "ItemCHERIBERRY, 3, #{label}, #{chosen}",
                     PokeAccess::Menus.focused_text(berry_picker([:CHERIBERRY, 3], mode, [])), mode.to_s
      end
    end
  end

  test "leaves the label out where the berry's data has none to show" do
    chosen = I18n.t(:bdx_chosen, :n => 0, :tot => 6)
    { "no data for the berry" => [{}, :Flavor],
      "no flavours" => [{ :CHERIBERRY => Berry.new(nil, "Blanda", 2.0, :RED) }, :Flavor],
      "no size" => [{ :CHERIBERRY => Berry.new({ "Seco" => 5 }, "Blanda", nil, :RED) }, :Size] }.each do |what, (data, mode)|
      with_berry_data(data) do
        assert_equal "ItemCHERIBERRY, 3, #{chosen}",
                     PokeAccess::Menus.focused_text(berry_picker([:CHERIBERRY, 3], mode, [])), what
      end
    end
  end

  test "says the flavour as the build paints it, through its _INTL" do
    with_berry_data(:CHERIBERRY => CHERI) do
      said = with_intl("Picante" => "Spicy") { PokeAccess::Menus.focused_text(berry_picker([:CHERIBERRY, 3], :Flavor, [])) }
      assert_equal "ItemCHERIBERRY, 3, Spicy, #{I18n.t(:bdx_chosen, :n => 0, :tot => 6)}", said
    end
  end

  test "reads a berry for a scene that keeps no choice by its count and the default colour label alone" do
    with_berry_data(:CHERIBERRY => CHERI) do
      bare = Object.new
      bare.instance_variable_set(:@count, 6)
      picker = berry_picker([:CHERIBERRY, 3], :Flavor, nil)
      picker.instance_variable_set(:@scene, bare)
      assert_equal "ItemCHERIBERRY, 3, Rojo", PokeAccess::Menus.focused_text(picker)
    end
  end

  test "reads nothing for a berry the game's item data cannot name" do
    with_berry_data(:CHERIBERRY => CHERI) do
      { "a blank name" => Struct.new(:name).new(""), "an item the data does not know" => nil }.each do |what, item|
        with_item_data(:CHERIBERRY => item) do
          assert_nil PokeAccess::Menus.focused_text(berry_picker([:CHERIBERRY, 3], :Flavor, [])), what
        end
      end
    end
  end

  test "reads a berry the pocket keeps no count of by its name" do
    with_berry_data(:CHERIBERRY => CHERI) do
      assert_equal "ItemCHERIBERRY, Picante, #{I18n.t(:bdx_chosen, :n => 0, :tot => 6)}",
                   PokeAccess::Menus.focused_text(berry_picker([:CHERIBERRY, nil], :Flavor, []))
    end
  end

  test "puts the berry's own sheet on the info key and its whole row on Ctrl+T" do
    with_berry_data(:CHERIBERRY => CHERI) do
      PokeAccess::Config.verbosity = :brief
      PokeAccess::Menus.focused_text(berry_picker([:CHERIBERRY, 3], :Flavor, []))
      row = "ItemCHERIBERRY, 3, Picante, #{I18n.t(:bdx_chosen, :n => 0, :tot => 6)}"
      assert_equal [PokeAccess::Info.item_info(:CHERIBERRY), row], [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
    end
  end

  test "reads the close row past the berries, and the info key knows" do
    picker = berry_picker([:CHERIBERRY, 3], :Flavor, [])
    picker.index = 1
    unfiltered = berry_picker([:CHERIBERRY, 3], :Flavor, [])
    unfiltered.instance_variable_set(:@filterlist, nil)
    close = I18n.t(:mn_close_bag)
    assert_equal [close, close], [PokeAccess::Menus.focused_text(picker), PokeAccess::Menus.focused_text(unfiltered)]
    assert_equal close, PokeAccess::Info.info_text
  end

  test "reads nothing for a row whose berry the pocket does not hold" do
    picker = berry_picker([:CHERIBERRY, 3], :Flavor, [])
    picker.instance_variable_set(:@filterlist, [4])
    assert_nil PokeAccess::Menus.focused_text(picker)
  end

  test "the opening's empty circles say nothing: the row says how many it takes" do
    ChooseBerryMultiple_Scene.new(3).drawSelectedBerries
    assert_nothing_spoken
  end

  test "a berry chosen says how many so far and which, queued and once" do
    s = ChooseBerryMultiple_Scene.new(3)
    s.drawSelectedBerries
    s.selectedBerries.push(Chosen.new(:ORAN, "Oran Berry"))
    2.times { s.drawSelectedBerries }
    s.selectedBerries.push(Chosen.new(:PECHA, "Pecha Berry"))
    s.drawSelectedBerries
    assert_equal [["#{I18n.t(:bdx_chosen, :n => 1, :tot => 3)}. Oran Berry", false],
                  ["#{I18n.t(:bdx_chosen, :n => 2, :tot => 3)}. Oran Berry, Pecha Berry", false]], SpeakCapture.log
  end

  private

  # A berry picker on a bag whose berry pocket holds entry alone, for a recipe of six, in a label mode, with these
  # berries chosen.
  def berry_picker(entry, mode, chosen)
    bag = Struct.new(:pockets).new([nil, nil, nil, nil, nil, [entry]])
    scene = Picker.new(chosen)
    scene.instance_variable_set(:@count, 6)
    scene.instance_variable_set(:@label, mode)
    Window_ChooseBerryMultiple.new(bag, [0], scene)
  end

  # Runs the block with the berry data the picker labels from: GameData::BerryData answering get from table (a berry
  # left out raises, as the game's does), red berries named by GameData::BerryColor, and every berry's Natural Gift
  # of the Fire type; whatever stood under those names put back after.
  def with_berry_data(table)
    held = [:BerryData, :BerryColor].map { |c| GameData.const_defined?(c, false) ? GameData.const_get(c) : nil }
    gift = Object.private_method_defined?(:pbBerryGetNaturalGift) ? Object.instance_method(:pbBerryGetNaturalGift) : nil
    [:BerryData, :BerryColor].each { |c| GameData.send(:remove_const, c) if GameData.const_defined?(c, false) }
    data = Class.new
    data.define_singleton_method(:get) { |b| table.fetch(b) }
    colors = Class.new
    colors.define_singleton_method(:get) { |c| Struct.new(:name).new({ :RED => "Rojo" }.fetch(c)) }
    GameData.const_set(:BerryData, data)
    GameData.const_set(:BerryColor, colors)
    Object.send(:define_method, :pbBerryGetNaturalGift) { |_item| [:FIRE, 80] }
    Object.send(:private, :pbBerryGetNaturalGift)
    yield
  ensure
    Object.send(:remove_method, :pbBerryGetNaturalGift) if Object.private_method_defined?(:pbBerryGetNaturalGift)
    (Object.send(:define_method, :pbBerryGetNaturalGift, gift); Object.send(:private, :pbBerryGetNaturalGift)) if gift
    [:BerryData, :BerryColor].each_with_index do |c, i|
      GameData.send(:remove_const, c) if GameData.const_defined?(c, false)
      GameData.const_set(c, held[i]) if held[i]
    end
  end

  # Runs the block with GameData::Item.get answering table's item for each id it lists (raising for nil, as the
  # game's does for an id it does not know) and the stub's own for the rest; the stub's put back after.
  def with_item_data(table)
    meta = GameData::Item.singleton_class
    meta.send(:alias_method, :pa_spec_item_get, :get)
    meta.send(:define_method, :get) do |id|
      next pa_spec_item_get(id) unless table.key?(id)
      table[id] || raise(ArgumentError, "unknown item #{id.inspect}")
    end
    yield
  ensure
    meta.send(:alias_method, :get, :pa_spec_item_get)
    meta.send(:remove_method, :pa_spec_item_get)
  end
end
