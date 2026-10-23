# Infinite Fusion 2's move picker for a fusion (games/infinitefusion_hoenn/fusion_moves.rb), over stand-ins shaped as
# its classes: the header row that takes every move of the head or of the body, four rows of two moves, Confirm, the
# moves taken and the counter of them, the box and the panel under the list, followed each frame of pbUpdate.

IfhFusionMove = Struct.new(:id)
IfhFusionSpecies = Struct.new(:name)
IfhFusionRow = Struct.new(:values)
IfhFusionText = Struct.new(:text)

# The options window, down to its rows' values, the column each row's cursor is on and the Confirm word it paints.
class Window_PokemonOptionFusionMoves
  attr_accessor :index
  def initialize(options, scene)
    @options = options
    @scene = scene
    @optvalues = [0] * options.length
    @index = 0
  end
  def [](i); @optvalues[i]; end
  def []=(i, v); @optvalues[i] = v; end
  def drawItem(index, _count, _rect)
    pbDrawShadowText(nil, 216, 0, 100, 32, "     Confirm") if index == @options.length
    :drawn
  end
end

# The picker: the head and body species, four slots of [left, right] moves, the moves taken and how many there can be;
# the box, the counter and the first row's stats panel, filled as the screen fills them.
class FusionMovesOptionsScene
  NAMES = { :TACKLE => "Tackle", :GROWL => "Growl", :EMBER => "Ember", :VINEWHIP => "Vine Whip",
            :MYSTERY => "Mystery" }
  DESCRIPTIONS = { :TACKLE => "A physical attack in which the user charges and slams into the target.",
                   :GROWL => "The user growls in an endearing way, making opposing Pokemon less wary.",
                   :EMBER => "The target is attacked with small flames. This may also leave the target with a burn.",
                   :VINEWHIP => "The target is struck with slender, whiplike vines to inflict damage." }
  attr_reader :selected_moves, :move_slots

  def initialize(slots)
    @head_species = IfhFusionSpecies.new("Bulbasaur")
    @body_species = IfhFusionSpecies.new("Charmander")
    @move_slots = slots.map { |pair| pair.map { |id| id ? IfhFusionMove.new(id) : nil } }
    @selected_moves = []
    @maxMovesNb = 4
    rows = [IfhFusionRow.new(["", ""])] + slots.map { |pair| IfhFusionRow.new(pair.map { |id| id ? NAMES[id] : "-" }) }
    @sprites = { "option" => Window_PokemonOptionFusionMoves.new(rows, self),
                 "titleMsg" => IfhFusionText.new("Select the moves you want to keep"),
                 "textbox" => IfhFusionText.new(""),
                 "counter" => IfhFusionText.new(_INTL("0 / {1}", @maxMovesNb)) }
  end

  # As the screen opens, before its first frame: the first row's box and panel, and the counter.
  def pbStartScene
    updateDescription(0)
    updateCounter
  end

  def updateCounter
    @sprites["counter"].text = _INTL("{1} / {2}", @selected_moves.length, @maxMovesNb)
  end

  # The fusion's stats on the panel, each label and its value at one height.
  def draw_pokemon_info
    pbDrawTextPositions(nil, [["HP", 20, 78], ["152", 158, 78], ["Attack", 20, 110], ["98", 158, 110],
                              ["Defense", 20, 142], ["83", 158, 142], ["Sp. Attack", 20, 174], ["70", 158, 174],
                              ["Sp. Defense", 20, 206], ["70", 158, 206], ["Speed", 20, 238], ["80", 158, 238]])
  end

  # The box for the cell at index: the first row's stats and what it takes, a move's description, an empty slot's line.
  def updateDescription(index)
    col = @sprites["option"][index] || 0
    if index == 0
      draw_pokemon_info
      species = col == 0 ? @head_species : @body_species
      @sprites["textbox"].text = _INTL("\nSelect all moves from {1}", species.name)
      return
    end
    slot = @move_slots[index - 1]
    return if !slot
    move = slot[col]
    @sprites["textbox"].text = move ? DESCRIPTIONS[move.id].to_s : _INTL("No move selected")
  end

  # A frame: the box follows the cell under the cursor, as the window flags it after a move.
  def pbUpdate
    updateDescription(@sprites["option"].index)
    :frame
  end
end

class IfhFusionMovesGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "fusion_moves.rb")
  SLOTS = [[:TACKLE, :EMBER], [:GROWL, nil], [:VINEWHIP, :GROWL], [nil, nil]]
  # The data the game keeps for each stand-in move: type name, power, accuracy, total PP and category; MYSTERY has none.
  MOVE_DATA = { :TACKLE => ["Normal", 40, 100, 35, 0], :EMBER => ["Fire", 40, 100, 25, 1],
                :GROWL => ["Normal", 0, 100, 40, 2], :VINEWHIP => ["Grass", 45, 100, 25, 0] }
  STATS = "HP 152. Attack 98. Defense 83. Sp. Attack 70. Sp. Defense 70. Speed 80"

  # Evaluates the profile file once, as boot does, its hooks bound to the stand-ins above; the profile list and the
  # overrides it adds are put back.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  test "the picker opens on its title, the counter and the header row as they are painted, queued" do
    open_picker
    line = PokeAccess.sentences(["Select the moves you want to keep", "0 / 4", "Select all moves from Bulbasaur"])
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "the header names the body by its box once the cursor goes right" do
    s = open_picker
    at(s, 0, 1)
    assert_equal ["Select all moves from Charmander", true], SpeakCapture.log.last
  end

  test "the header and the counter are said in the language the game paints them" do
    with_intl("\nSelect all moves from {1}" => "\nScegli tutte le mosse di {1}", "{1} / {2}" => "{1} su {2}") do
      open_picker
    end
    line = PokeAccess.sentences(["Select the moves you want to keep", "0 su 4", "Scegli tutte le mosse di Bulbasaur"])
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "the info key on the header row keeps the fusion's stats its panel paints" do
    open_picker
    assert_equal STATS, PokeAccess::Info.info_text
  end

  test "a move row says its data and the description its box paints by the learn move reading's level" do
    lines = vb_levels do
      s = open_picker
      at(s, 1, 0)
      SpeakCapture.log.last
    end
    type = t(:mv_type, :t => "Normal")
    assert_equal [["Tackle", true], ["Tackle. #{type}", true], [tackle("Tackle"), true]], lines
  end

  test "a move row says the move in the column the cursor is on, cutting in, and an empty slot as such" do
    s = open_picker
    at(s, 1, 0)
    at(s, 1, 1)
    at(s, 2, 1)
    ember = ["Ember", t(:mv_type, :t => "Fire"), t(:cat_special), t(:mv_power, :p => "40"), t(:mv_acc, :a => 100),
             t(:mv_pp, :pp => 25, :tot => 25), FusionMovesOptionsScene::DESCRIPTIONS[:EMBER]].join(". ")
    assert_equal [[tackle("Tackle"), true], [ember, true], [t(:row_empty), true]], SpeakCapture.log[1..-1]
  end

  test "the info key keeps the focused move whole whatever the verbosity, and an empty slot's box" do
    PokeAccess::Config.verbosity = :brief
    s = open_picker
    at(s, 1, 0)
    assert_equal ["Tackle", tackle("Tackle")], [SpeakCapture.last, PokeAccess::Info.info_text]
    at(s, 2, 1)
    assert_equal "No move selected", PokeAccess::Info.info_text
  end

  test "taking a move says it as taken with the painted counter, and leaving it again, without its data" do
    s = open_picker
    at(s, 3, 0)
    pick(s) { s.selected_moves.push(s.move_slots[2][0]) }
    assert_equal ["Vine Whip, #{t(:if2_fm_taken)}. 1 / 4", true], SpeakCapture.log.last
    pick(s) { s.selected_moves.clear }
    assert_equal ["Vine Whip. 0 / 4", true], SpeakCapture.log.last
  end

  test "a move taken is said as taken in the other row that holds it too, with its data and without the counter" do
    s = open_picker
    at(s, 2, 0)
    pick(s) { s.selected_moves.push(s.move_slots[1][0]) }
    at(s, 3, 1)
    growl = ["Growl, #{t(:if2_fm_taken)}", t(:mv_type, :t => "Normal"), t(:cat_status),
             t(:mv_power, :p => t(:mv_power_none)), t(:mv_acc, :a => 100), t(:mv_pp, :pp => 40, :tot => 40),
             FusionMovesOptionsScene::DESCRIPTIONS[:GROWL]].join(". ")
    assert_equal [growl, true], SpeakCapture.log.last
    assert_equal growl.sub("Growl, #{t(:if2_fm_taken)}", "Growl"), PokeAccess::Info.info_text
  end

  test "a move the game keeps no data or description for is said by its name alone, and so is its info" do
    s = open_picker([[:MYSTERY, nil], [nil, nil], [nil, nil], [nil, nil]])
    at(s, 1, 0)
    assert_equal [["Mystery", true], "Mystery"], [SpeakCapture.log.last, PokeAccess::Info.info_text]
  end

  test "Confirm is said by the word the window paints, with the painted counter, and so is its info" do
    s = open_picker
    win = s.instance_variable_get(:@sprites)["option"]
    assert_equal :drawn, win.drawItem(5, 6, nil)
    at(s, 1, 0)
    at(s, 5, 0)
    assert_equal [["Confirm. 0 / 4", true], "Confirm. 0 / 4"], [SpeakCapture.log.last, PokeAccess::Info.info_text]
  end

  test "the options reader leaves left and right on this window to the picker's reader" do
    s = open_picker
    assert_nil PokeAccess::Options.value_label(s.instance_variable_get(:@sprites)["option"], 1)
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Tackle's whole line after the given lead (its name, with whether it is taken).
  def tackle(lead)
    [lead, t(:mv_type, :t => "Normal"), t(:cat_physical), t(:mv_power, :p => "40"), t(:mv_acc, :a => 100),
     t(:mv_pp, :pp => 35, :tot => 35), FusionMovesOptionsScene::DESCRIPTIONS[:TACKLE]].join(". ")
  end

  # Opens a picker over slots and runs its first frame.
  def open_picker(slots = SLOTS)
    s = FusionMovesOptionsScene.new(slots)
    s.pbStartScene
    assert_equal :frame, frame(s)
    s
  end

  # A frame of the picker, the stand-in moves' data served as the game's provider would.
  def frame(scene)
    provider = Object.new
    [:move_type_name, :move_power, :move_accuracy, :move_total_pp, :move_category].each_with_index do |meth, i|
      provider.define_singleton_method(meth) { |id| (MOVE_DATA[id] || [])[i] }
    end
    Harness.with_provider(provider, 30) { scene.pbUpdate }
  end

  # Puts the cursor on row idx, column col, and runs a frame.
  def at(scene, idx, col)
    win = scene.instance_variable_get(:@sprites)["option"]
    win.index = idx
    win[idx] = col
    frame(scene)
  end

  # The use key on the focused move: the block takes or leaves it, the counter is repainted, then a frame runs.
  def pick(scene)
    yield
    scene.updateCounter
    frame(scene)
  end
end
