# The rows said while moving through menus, each at its reading's level (brief what a decision needs, medium a little
# more, full everything); what the info key says never changes with it.
class Window_PokemonMart; end unless defined?(Window_PokemonMart)

class VbSpecBag
  attr_reader :pockets
  def initialize(pockets, favs); @pockets = pockets; @favs = favs; end
  def favourite?(item); @favs.include?(item); end
end

class VbSpecBagAdapter
  def getDisplayName(item); item.to_s; end
  def getDescription(_item); ""; end
end

class VbSpecBagWindow
  attr_accessor :index
  def initialize(bag); @bag = bag; @adapter = VbSpecBagAdapter.new; @index = 0; end
  def pocket; 1; end
  def itemCount; @bag.pockets[1].length + 1; end
end

Suite.define("verbosity readings: a party member says its name, HP and state, the level from medium") do
  t = PokeAccess::I18n
  pk = Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :status => 1, :item => 25, :shiny => true)
  rows = vb_levels { PokeAccess::Party.member_line(pk) }
  eq "brief: name, HP and the state", rows[0],
     [t.t(:pty_member_nolv, :name => "Bulba", :sex => "", :hp => 20, :tot => 20), t.t(:st_sleep)].join(", ")
  eq "medium: and the level", rows[1],
     [t.t(:pty_member, :name => "Bulba", :sex => "", :level => 5, :hp => 20, :tot => 20), t.t(:st_sleep)].join(", ")
  truthy "full: the sex, the shiny star and the held item as well",
         rows[2].include?("Bulba \xE2\x99\x82") && rows[2].include?(t.t(:pk_shiny)) && rows[2].include?(t.t(:pty_item))
  able = vb_levels { PokeAccess::Party.member_line(pk, :annotation => "APTO") }
  eq "the able or not able a panel writes is kept in brief", able[0],
     [t.t(:pty_head_nolv, :name => "Bulba", :sex => ""), "APTO"].join(", ")
  fainted = Poke.build(:name => "Dead", :level => 9, :hp => 0, :totalhp => 24)
  truthy "and so is fainted", vb_levels { PokeAccess::Party.member_line(fainted) }[0].include?(t.t(:pk_fainted))
end

Suite.define("verbosity readings: a stored Pokemon says its name and level, where it sits and its item from medium") do
  t = PokeAccess::I18n
  pk = Poke.build(:name => "Bulba", :level => 5, :shiny => true)
  pos = t.t(:pc_pos, :row => 1, :col => 2)
  rows = vb_levels { PokeAccess::Party.pc_line(pk, pos) }
  eq "brief: the name and the level", rows[0], t.t(:pc_slot, :name => "Bulba", :level => 5)
  eq "medium: where it sits and its item", rows[1],
     [t.t(:pc_slot, :name => "Bulba", :level => 5) + pos, t.t(:pc_no_item)].join(", ")
  truthy "full: the sex, the shiny star and the ability as well",
         rows[2].include?("Bulba \xE2\x99\x82") && rows[2].include?(t.t(:pk_shiny)) && rows[2].include?(t.t(:pc_ability, :a => PokeAccess::Data.ability_name(1)))
  boxes = vb_levels { PokeAccess::Party.box_row("Caja 1") }
  eq "the box row keeps its name and says its keys from medium", boxes,
     [t.t(:pc_box, :name => "Caja 1"), [t.t(:pc_box, :name => "Caja 1"), t.t(:pc_box_hint)].join(". "),
      [t.t(:pc_box, :name => "Caja 1"), t.t(:pc_box_hint)].join(". ")]
end

Suite.define("verbosity readings: a move says its name and PP, the type from medium, and the info key all of it") do
  mi = PokeAccess::MoveInfo
  t = PokeAccess::I18n
  opts = { :cat => t.t(:cat_special), :pp => 15, :total_pp => 15, :desc => "Puede paralizar." }
  full = mi.line("Rayo", "Electrico", 90, 100, opts)
  battle = vb_levels { mi.leveled(:battle_move, "Rayo", "Electrico", 90, 100, opts) }
  eq "in battle: name and PP, then the type, then everything", battle,
     [mi.line("Rayo", nil, nil, nil, :pp => 15, :total_pp => 15),
      mi.line("Rayo", "Electrico", nil, nil, :pp => 15, :total_pp => 15), full]
  summary = vb_levels { mi.leveled(:summary_move, "Rayo", "Electrico", 90, 100, opts) }
  eq "the summary's moves read like the fight's", summary, battle
  learn = vb_levels { mi.leveled(:learn_move, "Rayo", "Electrico", 90, 100, opts) }
  eq "learning one: the name, then the type, then everything", learn,
     [mi.line("Rayo", nil, nil, nil), mi.line("Rayo", "Electrico", nil, nil), full]
  eq "with no reading the line is the info key's, whole at any level",
     vb_levels { mi.leveled(nil, "Rayo", "Electrico", 90, 100, opts) }.uniq, [full]
  eq "and the info key's line for a move id does not change either",
     vb_levels { mi.by_id_via_data(5).to_s }.uniq.length, 1
end

Suite.define("verbosity readings: the gen-6 fight menu in brief says the move and its PP") do
  t = PokeAccess::I18n
  mv = Object.new
  mv.instance_variable_set(:@category, 0)
  def mv.id; 7; end
  def mv.name; "Placaje"; end
  def mv.type; 0; end
  def mv.pp; 30; end
  def mv.totalpp; 35; end
  lines = vb_levels do
    disp = Object.new
    disp.instance_variable_set(:@battler, Struct.new(:moves).new([mv]))
    disp.instance_variable_set(:@index, 0)
    SpeakCapture.clear
    PokeAccess::Battle.read_fight_move(disp)
    SpeakCapture.last
  end
  pp = t.t(:mv_pp, :pp => 30, :tot => 35)
  ty = t.t(:mv_type, :t => PBTypes.getName(0))
  eq "brief, medium and full", lines,
     ["Placaje. #{pp}", "Placaje. #{ty}. #{pp}", "Placaje. #{ty}. #{t.t(:cat_physical)}. #{pp}"]
end

Suite.define("verbosity readings: the bag keeps the count and the move, its marks from medium") do
  t = PokeAccess::I18n
  bag = VbSpecBag.new({ 1 => [[:POTION, 3], [:REPEL, 1]] }, [:POTION])
  win = VbSpecBagWindow.new(bag)
  rows = vb_levels { PokeAccess::Menus.bag_row(win, 0) }
  eq "brief says the item and how many", rows[0], "POTION: 3"
  eq "medium and full add the favourite mark", rows[1..2], ["POTION: 3, #{t.t(:mb_favourite)}"] * 2
  win.instance_variable_set(:@sortIndex, 1)
  eq "and an item being moved says so even in brief", vb_levels { PokeAccess::Menus.bag_row(win, 1) }[0],
     "REPEL: 1, #{t.t(:bag_moving)}"
end

Suite.define("verbosity readings: a shop row keeps its price, and the count in the bag waits for medium") do
  inner = Object.new
  def inner.isWornItem?(item); item == :TOPHAT; end
  ad = Object.new
  ad.instance_variable_set(:@inner, inner)
  def ad.getAdapter; @inner; end
  def ad.getDisplayName(item); { :TOPHAT => "Chistera" }[item]; end
  def ad.getDisplayPrice(_item); "$500"; end
  win = Window_PokemonMart.new
  win.instance_variable_set(:@stock, [:TOPHAT])
  win.instance_variable_set(:@adapter, ad)
  def win.index; 0; end
  eq "the name, the price and what is worn, in brief too",
     vb_levels { PokeAccess::Menus.focused_text(win) }[0], "Chistera, $500, #{PokeAccess::I18n.t(:shop_worn)}"

  scene_class = Class.new do
    attr_reader :sprites
    def initialize; @sprites = { "qtywindow" => FakeTextWin.new }; end
  end
  Object.const_set(:VbSpecShopScene, scene_class) unless defined?(VbSpecShopScene)
  iw = PokeAccess::InfoWindow
  prev = iw.live
  begin
    iw.watch("VbSpecShopScene", "qtywindow", :vb_spec_qty, :reading => [:shop_item, :medium])
    scene = VbSpecShopScene.new
    iw.enter(scene)
    scene.sprites["qtywindow"].text = "En la mochila: 2"
    PokeAccess::Config.verbosity = :brief
    SpeakCapture.clear
    iw.tick
    silent "in brief the count in the bag is not said"
    eq "and Ctrl+T says it after the row", PokeAccess::Info.row_text,
       "Chistera, $500, #{PokeAccess::I18n.t(:shop_worn)}. En la mochila: 2"
    PokeAccess::Config.verbosity = :medium
    iw.tick
    eq "from medium it is", SpeakCapture.lines, ["En la mochila: 2"]
  ensure
    PokeAccess::Config.verbosity = :full
    iw.watches.reject! { |w| w[0].to_s == "VbSpecShopScene" }
    iw.enter(prev)
  end
end

Suite.define("verbosity readings: a Pokedex row says its number and name, caught or seen from medium") do
  t = PokeAccess::I18n
  had = $player
  begin
    player = Object.new
    def player.seen?(sp); sp != 3; end
    def player.owned?(sp); sp == 1; end
    $player = player
    eq "caught", vb_levels { PokeAccess::Menus.dex_row("001", 1, "Bulbasaur") },
       ["001, Bulbasaur", "001, Bulbasaur, #{t.t(:dex_caught)}", "001, Bulbasaur, #{t.t(:dex_caught)}"]
    eq "one never seen has only its number and unknown, at every level",
       vb_levels { PokeAccess::Menus.dex_row("003", 3, "Venusaur") }.uniq, ["003, #{t.t(:dex_unknown)}"]
  ensure
    $player = had
  end
end

Suite.define("verbosity readings: a summary page's key hints are said from medium") do
  lines = ["PS", "[C]: Descripcion"]
  pages = vb_levels { PokeAccess::Summary.with_hints("Estadisticas.", lines) }
  eq "brief leaves the hint out, medium and full say it", pages,
     ["Estadisticas.", "Estadisticas. [C]: Descripcion.", "Estadisticas. [C]: Descripcion."]
end

Suite.define("verbosity readings: a painted Pokedex page says number, name and caught, the category from medium") do
  t = PokeAccess::I18n
  rows = ["025 Pikachu", "Pokémon Ratón", "Altura: 0.4 m", "Peso: 6.0 kg", "Almacena electricidad."]
  levels = vb_levels { PokeAccess::DexEntry.painted_entry(rows, true, ["Eléctrico"]) }
  eq "brief: the first row and the caught mark", levels[0], "025 Pikachu, #{t.t(:dex_caught)}"
  eq "medium: the category and the types too", levels[1],
     "025 Pikachu, #{t.t(:dex_caught)}, Pokémon Ratón, #{t.t(:pdx_type, :t => "Eléctrico")}"
  truthy "full: the size and the entry as well", levels[2].end_with?("Almacena electricidad.")
  PokeAccess::Config.verbosity = :brief
  PokeAccess::DexEntry.painted_entry(rows, true, ["Eléctrico"])
  PokeAccess::Config.verbosity = :full
  eq "the info key keeps the whole page", PokeAccess::Info.info_text, levels[2]

  pk = Struct.new(:kind, :height, :weight, :dexEntry).new("Ratón", 4, 60, "Almacena electricidad.")
  name = PokeAccess::Data.species_name(25)
  composed = vb_levels { PokeAccess::DexEntry.gen6_composed(pk, 25, true) }
  eq "a composed page in brief: the name", composed[0], name
  eq "medium: and the category", composed[1], "#{name}. #{t.t(:dex_category, :cat => "Ratón")}"
  eq "one not caught says so at any level", vb_levels { PokeAccess::DexEntry.gen6_composed(pk, 25, false) }[0],
     "#{name}. #{t.t(:pdx_not_caught)}"
end

Suite.define("verbosity readings: at any level the info key says the sheet and Ctrl+T the row whole") do
  pk = Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :status => 1, :item => 25, :shiny => true)
  full = vb_levels { PokeAccess::Party.party_line([pk], 0) }[2]
  PokeAccess::Config.verbosity = :brief
  PokeAccess::Party.party_line([pk], 0)
  eq "a party member: the glance on the info key", PokeAccess::Info.info_text, PokeAccess::Info.pokemon_info(pk)
  eq "and its full row on Ctrl+T", PokeAccess::Info.row_text, full

  pcfull = vb_levels { PokeAccess::Party.slot_line(Object.new, 1, false, pk, nil, "") }[2]
  PokeAccess::Config.verbosity = :brief
  PokeAccess::Party.slot_line(Object.new, 1, false, pk, nil, "")
  eq "a PC slot: the glance on the info key", PokeAccess::Info.info_text, PokeAccess::Info.pokemon_info(pk)
  eq "and its full row on Ctrl+T, no part said twice", PokeAccess::Info.row_text, pcfull

  win = VbSpecBagWindow.new(VbSpecBag.new({ 1 => [[:POTION, 3]] }, [:POTION]))
  bagfull = vb_levels { PokeAccess::Menus.bag_row(win, 0) }[2]
  PokeAccess::Config.verbosity = :brief
  PokeAccess::Menus.bag_row(win, 0)
  eq "a bag row: the item's sheet on the info key", PokeAccess::Info.info_text, PokeAccess::Info.item_info(:POTION)
  eq "and its full row on Ctrl+T", PokeAccess::Info.row_text, bagfull
  PokeAccess::Config.verbosity = :full
end

Suite.define("verbosity readings: an item's sheet never doubles a stop before the move a machine teaches") do
  data = PokeAccess::Data
  desc = data.method(:item_description)
  machine = PokeAccess::Info.method(:machine_move)
  data.define_singleton_method(:item_description) { |_id| "Lanza un rayo potente." }
  PokeAccess::Info.define_singleton_method(:machine_move) { |_id| 85 }
  begin
    sheet = PokeAccess::Info.item_info(1).to_s
    falsy "no two stops in a row", sheet.include?("..")
    truthy "and the move it teaches follows", sheet.include?(PokeAccess::I18n.t(:it_teaches, :move => PokeAccess::Data.move_name(85)))
  ensure
    data.define_singleton_method(:item_description, desc)
    PokeAccess::Info.define_singleton_method(:machine_move, machine)
  end
end
