# Secret bases, gamedata pass: the decoration shop's own prompts and money (the plugin's SecretBaseMart_Scene, an
# engine stub, and Royal's wall and floor shop, a stand-in made before its profile file loads), what the removing
# cursor stands on, and a decoration's description on the info key.
module GameData
  # The decorations the spec places: a Pikachu cushion (1x1, set on top), a red mat (2x2) and a desk (2x1) from the
  # tileset, and a tall doll (1x2) that is an event's sprite, with no tile offset.
  class SecretBaseDecoration
    ROWS = { :PIKACHUCUSHION => ["Cojín Pikachu", [1, 1], :decor, 12], :REDMAT => ["Alfombra roja", [2, 2], :mat, 40],
             :DESK => ["Escritorio", [2, 1], :floor, 45], :BIGDOLL => ["Muñeco grande", [1, 2], :floor, nil] }
    def self.get(id); ROWS[id] ? new(id) : raise(ArgumentError, "no decoration #{id}"); end
    def initialize(id); @id = id; end
    def name; ROWS[@id][0]; end
    def tile_size; ROWS[@id][1]; end
    def permission; ROWS[@id][2]; end
    def tile_offset; ROWS[@id][3]; end
    def description; "#{name}, para la base."; end
  end
end unless defined?(GameData::SecretBaseDecoration)

class SecretBaseMartParedSuelo_Scene
  attr_reader :sprites
  def initialize; @sprites = { "moneywindow" => FakeTextWin.new("Dinero:\r\n<r>$900") }; end
  def pbStartBuyScene(*_a); :buy; end
  def pbStartSellScene(*_a); :sell; end
  def pbEndBuyScene; :end_buy; end
  def pbEndSellScene; :end_sell; end
  def pbDisplay(msg, _brief = false); msg; end
  def pbDisplayPaused(msg); msg; end
  def pbConfirm(_msg); false; end
end

load File.expand_path("../../../games/royal/secret_base_shop.rb", File.dirname(__FILE__))

Suite.define("secret base shop: its own prompts, results and money are said") do
  shop = SecretBaseMart_Scene.new("$1.500")
  question = "¿Así que quieres Cojín Pikachu?\nSerían $300. ¿Te parece bien?"
  SpeakCapture.clear
  eq "the question keeps the shop's own answer", shop.pbConfirm(question), true
  eq "and is said before its choices", SpeakCapture.lines, [PokeAccess.clean(question)]
  SpeakCapture.clear
  shop.pbDisplayPaused("¡Gracias!\nTe lo enviaré al PC de tu casa.")
  shop.pbDisplay("No tienes suficiente dinero.")
  eq "the results as well", SpeakCapture.lines,
     [PokeAccess.clean("¡Gracias!\nTe lo enviaré al PC de tu casa."), "No tienes suficiente dinero."]

  money = PokeAccess.clean_fields("Dinero:\r\n<r>$1.500")
  SpeakCapture.clear
  eq "the frame update keeps its own value", shop.update, :updated
  eq "the money on the first frame, queued", SpeakCapture.log, [[money, false]]
  SpeakCapture.clear
  shop.update
  silent "and not again while it stays"
  shop.sprites["moneywindow"].text = "Dinero:\r\n<r>$1.200"
  SpeakCapture.clear
  shop.update
  eq "a purchase changes it, and it is said again", SpeakCapture.lines, [PokeAccess.clean_fields("Dinero:\r\n<r>$1.200")]
  shop.sprites["moneywindow"].visible = false
  shop.sprites["moneywindow"].text = "Dinero:\r\n<r>$1.000"
  SpeakCapture.clear
  shop.update
  silent "a hidden money window says nothing"
end

# The buy list's focused decoration: its description comes from the shop's adapter, which the mod's item data does
# not know; selling runs the base's own list as a subscene, which says its own.
Suite.define("secret base shop: the focused decoration's description, in full after its row, once per decoration") do
  adapter = Object.new
  adapter.define_singleton_method(:getDisplayName) { |i| i == :DESK ? "Escritorio" : "Silla" }
  adapter.define_singleton_method(:getDescription) { |i| i == :DESK ? "Un escritorio pequeño." : "Una silla." }
  list = Struct.new(:item).new(:DESK)
  shop = SecretBaseMart_Scene.new("$1.500")
  shop.instance_variable_set(:@adapter, adapter)
  shop.sprites["itemwindow"] = list
  shop.sprites["moneywindow"].visible = false
  SpeakCapture.clear
  shop.update
  eq "full: the description, queued after the row", SpeakCapture.log, [["Un escritorio pequeño.", false]]
  eq "the info key keeps the name with it", PokeAccess::Info.info_text, "Escritorio. Un escritorio pequeño."
  SpeakCapture.clear
  shop.update
  silent "and once per decoration"
  PokeAccess::Config.verbosity = :medium
  begin
    list.item = :CHAIR
    SpeakCapture.clear
    shop.update
    silent "medium: not said"
    eq "though the info key has it", PokeAccess::Info.info_text, "Silla. Una silla."
  ensure
    PokeAccess::Config.verbosity = :full
  end
  shop.instance_variable_set(:@subscene, Object.new)
  list.item = :DESK
  SpeakCapture.clear
  shop.update
  silent "selling, the base's list says its own"
end

Suite.define("royal wall and floor shop: its prompts and its money window, from the opening") do
  iw = PokeAccess::InfoWindow
  prev_live = iw.live
  begin
    shop = SecretBaseMartParedSuelo_Scene.new
    SpeakCapture.clear
    eq "the question keeps the shop's own answer", shop.pbConfirm("¿Así que quieres Pared de ladrillo?"), false
    eq "and is said", SpeakCapture.lines, ["¿Así que quieres Pared de ladrillo?"]
    SpeakCapture.clear
    eq "the opening keeps its own value", shop.pbStartBuyScene([], nil), :buy
    iw.tick
    eq "the money from the opening", SpeakCapture.lines, [PokeAccess.clean_fields("Dinero:\r\n<r>$900")]
    shop.pbEndBuyScene
    shop.sprites["moneywindow"].text = "Dinero:\r\n<r>$100"
    SpeakCapture.clear
    iw.tick
    silent "and nothing once the shop is closed"
  ensure
    iw.enter(prev_live)
  end
end

Suite.define("secret bases: the removing cursor says what the tile holds, the top one first") do
  t = PokeAccess::I18n
  sb = PokeAccess::SecretBases
  base = Struct.new(:decorations).new([[:REDMAT, 5, 5], [:PIKACHUCUSHION, 4, 4], nil, [:DESK, 9, 2], [:GONE, 1, 1],
                                       [:BIGDOLL, 7, 7]])
  eq "a cushion on a mat, the cushion first as removing takes it", sb.names_at(base, 4, 4),
     ["Cojín Pikachu", "Alfombra roja"]
  eq "the mat's other tiles hold the mat", sb.names_at(base, 5, 4), ["Alfombra roja"]
  eq "a piece anchored at its bottom-right tile covers the tiles left of it", sb.names_at(base, 8, 2), ["Escritorio"]
  eq "an event's sprite is found on its bottom row", sb.names_at(base, 7, 7), ["Muñeco grande"]
  eq "and not above it, where removing finds nothing", sb.names_at(base, 7, 6), []
  eq "an empty tile holds nothing", sb.names_at(base, 3, 3), []
  eq "nor does one whose decoration the data lacks", sb.names_at(base, 1, 1), []
  eq "the slots keep their decorations", base.decorations.compact.length, 5

  scene = World.stub_scene(:@cursor_x => 4, :@cursor_y => 4, :@item => nil, :@base => base)
  SpeakCapture.clear
  sb.focus(scene)
  eq "the tile and what it holds", SpeakCapture.lines,
     ["#{t.t(:mg_rowcol, :row => 4, :col => 4)}, Cojín Pikachu, Alfombra roja"]
  scene.instance_variable_set(:@cursor_x, 3)
  scene.instance_variable_set(:@cursor_y, 3)
  SpeakCapture.clear
  sb.focus(scene)
  eq "or that it holds none", SpeakCapture.lines, ["#{t.t(:mg_rowcol, :row => 3, :col => 3)}, #{t.t(:sb_nothing)}"]
  PokeAccess::Config.verbosity = :brief
  scene.instance_variable_set(:@cursor_x, 8)
  scene.instance_variable_set(:@cursor_y, 2)
  SpeakCapture.clear
  sb.focus(scene)
  eq "said at every level", SpeakCapture.lines, ["#{t.t(:mg_rowcol, :row => 2, :col => 8)}, Escritorio"]
  PokeAccess::Config.verbosity = :full
end

Suite.define("secret bases: a decoration row says its description in full, and the info key keeps it") do
  bag = Object.new
  bag.define_singleton_method(:pockets) { [nil, [[:PIKACHUCUSHION, 1], [:REDMAT, 1]]] }
  bag.define_singleton_method(:is_placed?) { |_pocket, i| i == 1 }
  win = Object.new
  win.instance_variable_set(:@bag, bag)
  win.instance_variable_set(:@pocket, 1)
  sb = PokeAccess::SecretBases
  whole = "Cojín Pikachu. Cojín Pikachu, para la base."
  eq "full: the name, then the description the list shows beside it", sb.decoration_text(win, 0, GameData::SecretBaseDecoration),
     whole
  eq "the info key keeps both", PokeAccess::Info.info_text, whole
  eq "and Ctrl+T says them too", PokeAccess::Info.row_text, whole
  placed = PokeAccess::I18n.t(:sb_placed, :name => "Alfombra roja")
  PokeAccess::Config.verbosity = :medium
  begin
    eq "medium: the row alone, a placed one saying so", sb.decoration_text(win, 1, GameData::SecretBaseDecoration), placed
    eq "while the info key still has its description", PokeAccess::Info.info_text, "#{placed}. Alfombra roja, para la base."
  ensure
    PokeAccess::Config.verbosity = :full
  end
end
