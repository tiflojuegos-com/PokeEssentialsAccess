# The rows said while moving through menus, each at its reading's level (brief what a decision needs, medium a little
# more, full everything); the info key and Ctrl+T say them whole at any level.

# The shop's item list window, which the mod reads by its extractor for this class.
class Window_PokemonMart; end unless defined?(Window_PokemonMart)

# A bag as the bag window reads it: its pockets of [item, count] and its favourites.
class VbSpecBag
  attr_reader :pockets
  def initialize(pockets, favs); @pockets = pockets; @favs = favs; end
  def favourite?(item); @favs.include?(item); end
end

# The bag's adapter: an item's name is its id, with no description.
class VbSpecBagAdapter
  def getDisplayName(item); item.to_s; end
  def getDescription(_item); ""; end
end

# The bag window on the first pocket, its rows the pocket's items and the close row.
class VbSpecBagWindow
  attr_accessor :index
  def initialize(bag); @bag = bag; @adapter = VbSpecBagAdapter.new; @index = 0; end
  def pocket; 1; end
  def itemCount; @bag.pockets[1].length + 1; end
end

# A shop screen with the window that shows how many of the focused item the bag holds.
class VbSpecShopScene
  attr_reader :sprites
  def initialize; @sprites = { "qtywindow" => FakeTextWin.new }; end
  def pbStartScene; :opened; end
end

class VerbosityReadingsTest < PokeAccessTest
  DEX_ROWS = ["025 Pikachu", "Pokémon Ratón", "Altura: 0.4 m", "Peso: 6.0 kg", "Almacena electricidad."]

  test "a party member says its name, HP and state in brief, and the level from medium" do
    assert_equal ["#{member_head(:brief)}, #{t(:st_sleep)}", "#{member_head(:medium)}, #{t(:st_sleep)}"],
                 vb_levels { PokeAccess::Party.member_line(member) }.first(2)
  end

  test "a party member in full adds the sex, the shiny star and the held item" do
    PokeAccess::Config.verbosity = :full
    assert_equal "#{member_head(:full)}, #{t(:st_sleep)}, #{t(:pk_shiny)}, #{t(:pty_item)}",
                 PokeAccess::Party.member_line(member)
  end

  test "a party member's pokerus, Exp. Share and panel icons are said only in full" do
    pk = Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20)
    def pk.pokerusStage; 1; end
    def pk.expshare; true; end
    opts = { :pokerus_slot => true, :marks => ["Marca"] }
    assert_equal [member_head(:brief), member_head(:medium),
                  "#{member_head(:full)}, #{t(:pk_pokerus)}, #{t(:pty_expshare)}, Marca"],
                 vb_levels { PokeAccess::Party.member_line(pk, opts) }
  end

  test "a party member's pokerus is said only where the panel shows it, in an empty state slot" do
    PokeAccess::Config.verbosity = :full
    healthy = member_head(:full)
    { "infected, its panel showing it" => [1, 0, true, "#{healthy}, #{t(:pk_pokerus)}"],
      "infected, its panel showing none" => [1, 0, false, healthy],
      "cured" => [2, 0, true, healthy],
      "infected and asleep" => [1, 1, true, "#{healthy}, #{t(:st_sleep)}"] }.each do |what, (stage, status, slot, said)|
      pk = Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :status => status)
      pk.define_singleton_method(:pokerusStage) { stage }
      assert_equal said, PokeAccess::Party.member_line(pk, :pokerus_slot => slot), what
    end
  end

  test "a panel that draws no star and no Exp. Share leaves them out even in full" do
    pk = member
    def pk.expshare; true; end
    PokeAccess::Config.verbosity = :full
    assert_equal "#{member_head(:full)}, #{t(:st_sleep)}, #{t(:pty_item)}",
                 PokeAccess::Party.member_line(pk, :shiny => false, :panel_marks => false)
  end

  test "the able or not able a panel writes stands for HP and state, kept in brief" do
    assert_equal ["#{t(:pty_head_nolv, :name => 'Bulba', :sex => '')}, APTO",
                  "#{t(:pty_head, :name => 'Bulba', :sex => '', :level => 5)}, APTO"],
                 vb_levels { PokeAccess::Party.member_line(member, :annotation => "APTO") }.first(2)
  end

  test "a fainted party member says so in brief" do
    fainted = Poke.build(:name => "Dead", :level => 9, :hp => 0, :totalhp => 24)
    PokeAccess::Config.verbosity = :brief
    assert_equal "#{t(:pty_member_nolv, :name => 'Dead', :sex => '', :hp => 0, :tot => 24)}, #{t(:pk_fainted)}",
                 PokeAccess::Party.member_line(fainted)
  end

  test "a stored Pokemon says its name and level in brief, and where it sits and its item from medium" do
    assert_equal [stored_head, "#{stored_head}#{pos}, #{t(:pc_no_item)}"],
                 vb_levels { PokeAccess::Party.pc_line(stored, pos) }.first(2)
  end

  test "a stored Pokemon in full adds the sex, the shiny star, its types and its ability" do
    pk = stored
    def pk.type1; 3; end
    def pk.type2; 4; end
    PokeAccess::Config.verbosity = :full
    assert_equal "#{stored_head(' ♂')}#{pos}, #{t(:pk_shiny)}, #{t(:pc_types, :t => 'Tipo3 Tipo4')}, " \
                 "#{t(:pc_ability, :a => 'Habilidad1')}, #{t(:pc_no_item)}", PokeAccess::Party.pc_line(pk, pos)
  end

  test "a stored Pokemon's item is named from its id or its own name" do
    named = Struct.new(:name).new("Baya")
    blank = Struct.new(:name).new("")
    PokeAccess::Config.verbosity = :medium
    { 25 => t(:pc_item, :i => "Repel"), :POTION => t(:pc_item, :i => "ItemPOTION"), named => t(:pc_item, :i => "Baya"),
      blank => t(:pc_no_item), 0 => t(:pc_no_item), nil => t(:pc_no_item) }.each do |item, said|
      pk = Poke.build(:name => "Bulba", :level => 5, :item => item)
      assert_equal "#{stored_head}#{pos}, #{said}", PokeAccess::Party.pc_line(pk, pos), item.inspect
    end
  end

  test "a stored Pokemon's ability is named from its id or its own name, and one with none says so" do
    PokeAccess::Config.verbosity = :full
    { 1 => t(:pc_ability, :a => "Habilidad1"), Struct.new(:name).new("Espesura") => t(:pc_ability, :a => "Espesura"),
      Struct.new(:name).new("") => t(:pc_no_ability), 0 => t(:pc_no_ability) }.each do |ability, said|
      pk = Poke.build(:name => "Bulba", :level => 5, :ability => ability)
      assert_equal "#{stored_head(' ♂')}#{pos}, #{said}, #{t(:pc_no_item)}", PokeAccess::Party.pc_line(pk, pos),
                   ability.inspect
    end
  end

  test "a stored egg says it is an egg, and where it sits from medium" do
    egg = stored
    def egg.egg?; true; end
    assert_equal [t(:pty_egg), "#{t(:pty_egg)}#{pos}", "#{t(:pty_egg)}#{pos}"],
                 vb_levels { PokeAccess::Party.pc_line(egg, pos) }
  end

  test "a box row says the box's name, and the keys that turn it from medium" do
    box = t(:pc_box, :name => "Lluvia")
    assert_equal [box, "#{box}. #{t(:pc_box_hint)}", "#{box}. #{t(:pc_box_hint)}"],
                 vb_levels { PokeAccess::Party.box_row("Lluvia") }
  end

  test "a move in battle or on the summary says its name and PP in brief, the type from medium, all of it in full" do
    [:battle_move, :summary_move].each do |reading|
      assert_equal ["Rayo. #{pp}", "Rayo. #{type}. #{pp}", whole_move],
                   vb_levels { PokeAccess::MoveInfo.leveled(reading, "Rayo", "Electrico", 90, 100, move_opts) },
                   reading.to_s
    end
  end

  test "a move to learn says its name in brief, the type from medium, the PP only in full" do
    assert_equal ["Rayo", "Rayo. #{type}", whole_move],
                 vb_levels { PokeAccess::MoveInfo.leveled(:learn_move, "Rayo", "Electrico", 90, 100, move_opts) }
  end

  test "a move line without a reading is whole at any level" do
    assert_equal [whole_move] * 3,
                 vb_levels { PokeAccess::MoveInfo.leveled(nil, "Rayo", "Electrico", 90, 100, move_opts) }
  end

  test "a move line leaves out the parts it lacks, and the PP without their total" do
    { "blank type, category and description, no accuracy" => [["Rayo", "", 90, nil, { :cat => "", :pp => 15,
        :total_pp => 15, :desc => "" }], "Rayo. #{t(:mv_power, :p => '90')}. #{pp}"],
      "PP without a total" => [["Rayo", nil, nil, nil, { :pp => 15 }], "Rayo"] }.each do |what, (args, said)|
      assert_equal said, PokeAccess::MoveInfo.leveled(nil, *args), what
    end
  end

  test "the info key's line for a move id is whole at every level" do
    whole = "Mov5. #{t(:mv_type, :t => 'Tipo0')}. #{t(:cat_status)}. #{t(:mv_power, :p => '45')}. " \
            "#{t(:mv_acc, :a => '100')}. #{t(:mv_pp, :pp => 15, :tot => 15)}"
    assert_equal [whole] * 3, vb_levels { PokeAccess::MoveInfo.by_id_via_data(5) }
  end

  test "the gen-6 fight menu says the move and its PP in brief, the type from medium, the category in full" do
    mv_pp = t(:mv_pp, :pp => 30, :tot => 35)
    ty = t(:mv_type, :t => PBTypes.getName(0))
    lines = vb_levels do
      SpeakCapture.clear
      PokeAccess::Battle.read_fight_move(fight_display)
      SpeakCapture.last
    end
    assert_equal ["Placaje. #{mv_pp}", "Placaje. #{ty}. #{mv_pp}", "Placaje. #{ty}. #{t(:cat_physical)}. #{mv_pp}"], lines
  end

  test "a bag row keeps the item and its count in brief, and the favourite mark and its place from medium" do
    win = VbSpecBagWindow.new(VbSpecBag.new({ 1 => [[:POTION, 3], [:REPEL, 1]] }, [:POTION]))
    marked = "POTION: 3, #{t(:mb_favourite)}, #{list_place(1, 3)}"
    assert_equal ["POTION: 3", marked, marked], vb_levels { PokeAccess::Menus.bag_row(win, 0) }
  end

  test "a bag item being moved says so even in brief" do
    win = VbSpecBagWindow.new(VbSpecBag.new({ 1 => [[:POTION, 3], [:REPEL, 1]] }, [:POTION]))
    win.instance_variable_set(:@sortIndex, 1)
    PokeAccess::Config.verbosity = :brief
    assert_equal "REPEL: 1, #{t(:bag_moving)}", PokeAccess::Menus.bag_row(win, 1)
  end

  test "a shop row keeps its name, its price and what is worn at every level" do
    assert_equal ["Chistera, $500, #{t(:shop_worn)}"] * 3, vb_levels { PokeAccess::Menus.focused_text(shop_window) }
  end

  test "the count in the bag beside a shop row waits for medium" do
    with_shop_scene do |scene|
      PokeAccess::Config.verbosity = :brief
      PokeAccess::InfoWindow.tick
      assert_nothing_spoken "brief"
      PokeAccess::Config.verbosity = :medium
      PokeAccess::InfoWindow.tick
      assert_equal [["En la mochila: 2", false]], SpeakCapture.log, "medium"
    end
  end

  test "the count in the bag joins the shop row Ctrl+T repeats, even in brief" do
    with_shop_scene do |_scene|
      PokeAccess::Config.verbosity = :brief
      PokeAccess::Menus.focused_text(shop_window)
      PokeAccess::InfoWindow.tick
      assert_equal "Chistera, $500, #{t(:shop_worn)}. En la mochila: 2", PokeAccess::Info.row_text
    end
  end

  test "a Pokedex row says its number and name in brief, and caught or seen from medium" do
    with_dex(:seen => [1, 2], :owned => [1]) do
      { 1 => t(:dex_caught), 2 => t(:dex_seen) }.each do |sp, state|
        assert_equal ["00#{sp}, Bulbasaur", "00#{sp}, Bulbasaur, #{state}", "00#{sp}, Bulbasaur, #{state}"],
                     vb_levels { PokeAccess::Menus.dex_row("00#{sp}", sp, "Bulbasaur") }, "species #{sp}"
      end
    end
  end

  test "a species never seen is its number and unknown at every level" do
    with_dex(:seen => [1], :owned => [1]) do
      assert_equal ["003, #{t(:dex_unknown)}"] * 3, vb_levels { PokeAccess::Menus.dex_row("003", 3, "Venusaur") }
    end
  end

  test "a summary page's key hints are said from medium" do
    assert_equal ["Estadisticas.", "Estadisticas. [C]: Descripcion.", "Estadisticas. [C]: Descripcion."],
                 vb_levels { PokeAccess::Summary.with_hints("Estadisticas.", ["PS", "[C]: Descripcion"]) }
  end

  test "a painted Pokedex page says number, name and caught in brief, category and types from medium, all in full" do
    caught = "025 Pikachu, #{t(:dex_caught)}"
    typed = "#{caught}, Pokémon Ratón, #{t(:pdx_type, :t => 'Eléctrico')}"
    assert_equal [caught, typed, "#{typed}, Altura: 0.4 m, Peso: 6.0 kg, Almacena electricidad."],
                 vb_levels { PokeAccess::DexEntry.painted_entry(DEX_ROWS, true, ["Eléctrico"]) }
  end

  test "the info key keeps the whole painted Pokedex page in brief" do
    PokeAccess::Config.verbosity = :brief
    PokeAccess::DexEntry.painted_entry(DEX_ROWS, true, ["Eléctrico"])
    assert_equal "025 Pikachu, #{t(:dex_caught)}, Pokémon Ratón, #{t(:pdx_type, :t => 'Eléctrico')}, " \
                 "Altura: 0.4 m, Peso: 6.0 kg, Almacena electricidad.", PokeAccess::Info.info_text
  end

  test "a composed Pokedex page says the name in brief, the category from medium, size and entry in full" do
    name = PokeAccess::Data.species_name(25)
    category = "#{name}. #{t(:dex_category, :cat => 'Ratón')}"
    assert_equal [name, category, "#{category}. #{t(:dex_height, :h => '0,4')}. #{t(:dex_weight, :w => '6,0')}. " \
                                  "Almacena electricidad."],
                 vb_levels { PokeAccess::DexEntry.gen6_composed(dex_pokemon, 25, true) }
  end

  test "a composed Pokedex page not caught says so at every level" do
    said = "#{PokeAccess::Data.species_name(25)}. #{t(:pdx_not_caught)}"
    assert_equal [said] * 3, vb_levels { PokeAccess::DexEntry.gen6_composed(dex_pokemon, 25, false) }
  end

  test "a party member's glance is on the info key and its whole row on Ctrl+T, even in brief" do
    PokeAccess::Config.verbosity = :brief
    PokeAccess::Party.party_line([member], 0)
    assert_equal [member_glance, "#{member_head(:full)}, #{t(:st_sleep)}, #{t(:pk_shiny)}, #{t(:pty_item)}"],
                 [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "a PC slot's glance is on the info key and its whole row on Ctrl+T, even in brief" do
    PokeAccess::Config.verbosity = :brief
    pk = member
    PokeAccess::Party.slot_line(Object.new, 1, false, pk, nil, "")
    assert_equal [member_glance, "#{stored_head(' ♂')}#{pos}, #{t(:pk_shiny)}, " \
                  "#{t(:pc_ability, :a => 'Habilidad1')}, #{t(:pc_item, :i => 'Repel')}"],
                 [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "a bag row's item sheet is on the info key and its whole row on Ctrl+T, even in brief" do
    win = VbSpecBagWindow.new(VbSpecBag.new({ 1 => [[:POTION, 3]] }, [:POTION]))
    PokeAccess::Config.verbosity = :brief
    PokeAccess::Menus.bag_row(win, 0)
    assert_equal ["ItemPOTION", "POTION: 3, #{t(:mb_favourite)}, #{list_place(1, 2)}"],
                 [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "an item's sheet ends the description once before the move a machine teaches" do
    with_machine_description("Lanza un rayo potente.", 85) do
      assert_equal "#{PokeAccess::Data.item_name(1)}. Lanza un rayo potente. " \
                   "#{t(:it_teaches, :move => PokeAccess::Data.move_name(85))}.", PokeAccess::Info.item_info(1)
    end
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  # A party member asleep, shiny and holding an item.
  def member
    Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :status => 1, :item => 25, :shiny => true)
  end

  # That member at a glance, as the info key says it: name, level and HP, its shiny mark, its sex sign, the item it
  # holds and its state.
  def member_glance
    "#{t(:pk_glance, :name => 'Bulba', :level => 5, :hp => 20, :tot => 20)} #{t(:pk_shiny)}. ♂. " \
      "#{t(:pk_holds, :item => 'Repel')}. #{t(:st_sleep)}."
  end

  # How the party panel's head of a healthy Bulba (level 5, 20 of 20 HP, male) is said at a level: name and HP in
  # brief, the level from medium, the species after the nickname and the sex sign in full.
  def member_head(level)
    { :brief => t(:pty_member_nolv, :name => "Bulba", :sex => "", :hp => 20, :tot => 20),
      :medium => t(:pty_member, :name => "Bulba", :sex => "", :level => 5, :hp => 20, :tot => 20),
      :full => t(:pty_member, :name => "Bulba, Especie1", :sex => " ♂", :level => 5, :hp => 20, :tot => 20) }[level]
  end

  # A shiny Pokemon in the PC, holding nothing.
  def stored
    Poke.build(:name => "Bulba", :level => 5, :shiny => true)
  end

  # A stored Bulba's name, with the sex sign given (the box writes it in full), and its level.
  def stored_head(sex = "")
    t(:pc_slot, :name => "Bulba#{sex}", :level => 5)
  end

  # Where a stored Pokemon sits, as the box clause says it.
  def pos
    t(:pc_pos, :row => 1, :col => 2)
  end

  def pp; t(:mv_pp, :pp => 15, :tot => 15); end

  def type; t(:mv_type, :t => "Electrico"); end

  # A special move's parts, as the screens hand them in.
  def move_opts
    { :cat => t(:cat_special), :pp => 15, :total_pp => 15, :desc => "Puede paralizar." }
  end

  # That move's whole line.
  def whole_move
    "Rayo. #{type}. #{t(:cat_special)}. #{t(:mv_power, :p => '90')}. #{t(:mv_acc, :a => '100')}. #{pp}. Puede paralizar."
  end

  # The gen-6 fight menu focused on its only move, a physical Placaje of the first type with 30 of 35 PP.
  def fight_display
    mv = World.stub_scene(:@category => 0)
    def mv.id; 7; end
    def mv.name; "Placaje"; end
    def mv.type; 0; end
    def mv.pp; 30; end
    def mv.totalpp; 35; end
    World.stub_scene(:@battler => Struct.new(:moves).new([mv]), :@index => 0)
  end

  # The shop's list focused on a top hat, priced and worn.
  def shop_window
    inner = Object.new
    def inner.isWornItem?(item); item == :TOPHAT; end
    ad = World.stub_scene(:@inner => inner)
    def ad.getAdapter; @inner; end
    def ad.getDisplayName(item); { :TOPHAT => "Chistera" }[item]; end
    def ad.getDisplayPrice(_item); "$500"; end
    win = Window_PokemonMart.new
    win.instance_variable_set(:@stock, [:TOPHAT])
    win.instance_variable_set(:@adapter, ad)
    def win.index; 0; end
    win
  end

  # Runs the block with the shop screen open, its count in the bag watched as the shop reading's medium part and
  # showing two; the watch and the screen watched before are put back afterwards.
  def with_shop_scene
    was = PokeAccess::InfoWindow.live
    PokeAccess::InfoWindow.watch("VbSpecShopScene", "qtywindow", :vb_spec_qty, :reading => [:shop_item, :medium])
    scene = VbSpecShopScene.new
    scene.pbStartScene
    scene.sprites["qtywindow"].text = "En la mochila: 2"
    SpeakCapture.clear
    yield scene
  ensure
    PokeAccess::InfoWindow.watches.reject! { |w| w[2] == :vb_spec_qty }
    PokeAccess::InfoWindow.enter(was)
  end

  # Runs the block with a player whose Pokedex has seen and caught these species, the player put back afterwards.
  def with_dex(dex)
    had = $player
    player = Object.new
    player.define_singleton_method(:seen?) { |sp| dex[:seen].include?(sp) }
    player.define_singleton_method(:owned?) { |sp| dex[:owned].include?(sp) }
    $player = player
    yield
  ensure
    $player = had
  end

  # The gen-6 Pokedex's dummy Pikachu: its category, height and weight in tenths, and its entry.
  def dex_pokemon
    Struct.new(:kind, :height, :weight, :dexEntry).new("Ratón", 4, 60, "Almacena electricidad.")
  end

  # Runs the block with every item described as desc and teaching move, the data put back afterwards; no
  # description a screen noted stands in for it.
  def with_machine_description(desc, move)
    data = PokeAccess::Data
    was_desc = data.method(:item_description)
    was_machine = PokeAccess::Info.method(:machine_move)
    data.define_singleton_method(:item_description) { |_id| desc }
    PokeAccess::Info.define_singleton_method(:machine_move) { |_id| move }
    PokeAccess::Info.note_item_desc(nil, nil)
    yield
  ensure
    data.define_singleton_method(:item_description, was_desc)
    PokeAccess::Info.define_singleton_method(:machine_move, was_machine)
  end
end
