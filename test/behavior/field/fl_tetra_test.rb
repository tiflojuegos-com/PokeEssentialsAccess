# FL's Poké Tetra (plugins/fl_tetra.rb) over stand-ins of its scene, screen and card: the rules and blocked squares as a
# duel opens, the hand, the rival's hand and the board read from the sprites their loops raise and place, each move
# with the squares it flips, the score and the board for the info key, the taken-square warning, and the deck chooser.
# The species are numbers under the gen-6 engine and symbols under GameData, as the game's own are; the same file runs
# in both passes (fl_tetra_gd_test.rb).

# The three classes the plugin hooks, cut down to the methods it binds: every loop runs the frames of the block it is
# given, and a move's closing calls hand the score over as the game's do.
module PokeTetra
  USE_PARTY = true
  HAND_SIZE = 6

  class Card
    WIDTH = 84
    HEIGHT = 84
    attr_reader :species, :type, :north, :east, :south, :west

    def initialize(species)
      @species = species
      n = species.to_s[/\d+/].to_i
      @type = (ENGINE == :gamedata ? [:TYPE0, :TYPE1, :TYPE2] : [0, 1, 2])[n % 3]
      @north = n % 10
      @east = (n + 3) % 10
      @south = (n + 5) % 10
      @west = (n + 7) % 10
    end

    def createBitmap(owner, colors); [self, owner, colors]; end
  end

  class Square
    attr_accessor :owner, :card

    def initialize
      @owner = 0
      @card = nil
    end
  end

  class Screen
    attr_reader :width, :height, :board, :opponentName, :playerName
    attr_accessor :openHand, :countUnplayedCards

    def initialize(foe = "Hilbert", width = 4, height = 4)
      @width = width
      @height = height
      @board = Array.new(width * height) { Square.new }
      @opponentName = foe
      @playerName = "Ethan"
      @openHand = false
      @countUnplayedCards = false
    end

    def getPanel(x, y); @board[y * @width + x]; end
    def isOccupied?(x, y); getPanel(x, y).owner != 0; end
  end

  class Scene
    FIELD_BASE_X = 88
    FIELD_BASE_Y = 46

    def initialize(ivars = {})
      ivars.each { |name, value| instance_variable_set(name, value) }
    end

    def pbStartScene(battle); @battle = battle; end
    def pbPutBlockCards(_blocks); nil; end
    def pbDisplay(_text); nil; end
    def pbDisplayPaused(_text); nil; end
    def pbUpdateScore; nil; end
    def pbEndScene; nil; end
    def pbPlayerChooseCard(_num_cards); yield if block_given?; 0; end
    def pbViewOpponentCards(_num_cards); yield if block_given?; -1; end
    def pbPlayerPlaceCard(_card, _card_index); yield if block_given?; [0, 0]; end
    def pbChooseCard(_storage); yield if block_given?; []; end

    def pbEndPlaceCard(_position, card_index)
      @cardIndexes.delete_at(card_index) if @cardIndexes
      pbUpdateScore
    end

    def pbEndOpponentPlaceCard(_position, card_index)
      @opponentCardIndexes.delete_at(card_index) if @opponentCardIndexes
      pbUpdateScore
    end
  end
end

path = File.join(Harness::ROOT, "plugins", "fl_tetra.rb")
src = Harness.source(path)
at = src.index(/^PokeAccess::(Hooks|SceneWatcher)\./)
eval(src[at..-1], TOPLEVEL_BINDING, path, src[0, at].count("\n") + 1)

class FlTetraTest < PokeAccessTest
  Pic = Struct.new(:x, :y, :z, :visible, :bitmap)
  Box = Struct.new(:text)

  # A sprite the game has disposed, which raises when it is asked anything.
  class DeadPic
    def visible; raise "disposed sprite"; end
    def bitmap; raise "disposed sprite"; end
    def z; raise "disposed sprite"; end
  end

  # A data provider whose tables name neither species nor types, answering what it is given for both.
  class NamelessData
    def initialize(answer); @answer = answer; end
    def species_name(_id); @answer; end
    def type_name(_id); @answer; end
  end

  TEXTS = {
    "ttr_duel" => "Duelo de cartas contra %{foe}", "ttr_rules" => "Reglas: %{list}",
    "ttr_rule_open" => "mano abierta", "ttr_rule_same" => "los empates capturan",
    "ttr_rule_wrap" => "bordes conectados", "ttr_rule_random" => "mano al azar",
    "ttr_rule_count" => "cuentan las cartas sin jugar", "ttr_rule_notype" => "sin bonificación de tipo",
    "ttr_rule_direct" => "cada jugador conserva las cartas de su color",
    "ttr_rule_winall" => "el ganador se lleva todas las cartas",
    "ttr_board" => "Tablero de %{rows} filas por %{cols} columnas", "ttr_open_hint" => "%{key}: ver las cartas del rival",
    "ttr_blocks.one" => "casilla bloqueada: %{list}", "ttr_blocks.other" => "casillas bloqueadas: %{list}",
    "ttr_blocked" => "bloqueada", "ttr_you_play" => "Tu jugada: %{card}, en fila %{row}, columna %{col}",
    "ttr_occupied" => "Casilla ocupada", "ttr_chosen" => "cartas elegidas: %{n} de %{max}",
    "ttr_row" => "fila %{row}: %{cells}"
  }.freeze

  def setup
    super
    table = PokeAccess::I18n.table(:es)
    @injected = TEXTS.keys.reject { |key| table.key?(key) }
    @injected.each { |key| table[key] = TEXTS[key] }
  end

  def teardown
    table = PokeAccess::I18n.table(:es)
    @injected.each { |key| table.delete(key) }
    super
  end

  test "every hook of the plugin finds its method on the screen's classes" do
    assert_equal [], PokeAccess::Hooks.missing.select { |m| m =~ /PokeTetra/ }
  end

  test "a card is read as its species, its type and its four sides, top first" do
    line = "#{sp_name(4)}, #{t(:mv_type, :t => PokeAccess::Data.type_name(card(4).type))}"
    assert_equal t(:triad_card, :name => line, :n => 4, :e => 7, :s => 9, :w => 1), PokeAccess::Tetra.card_text(card(4))
  end

  test "a species the engine has no name for is read by its id, and a type with no name is left out" do
    [nil, ""].each do |answer|
      Harness.with_provider(NamelessData.new(answer), 30) do
        assert_equal t(:triad_card, :name => sp(4).to_s, :n => 4, :e => 7, :s => 9, :w => 1),
                     PokeAccess::Tetra.card_text(card(4)), "names answered #{answer.inspect}"
      end
    end
  end

  test "a duel opens with who it is against, its rules, the board's size and the key for an open hand" do
    battle = PokeTetra::Screen.new("Hilbert")
    battle.openHand = true
    battle.instance_variable_set(:@sameWins, true)
    PokeTetra::Scene.new.pbStartScene(battle)
    rules = t(:ttr_rules, :list => [t(:ttr_rule_open), t(:ttr_rule_same)].join(", "))
    assert_equal [[PokeAccess.sentences([t(:ttr_duel, :foe => "Hilbert"), rules, t(:ttr_board, :rows => 4, :cols => 4),
                                         t(:ttr_open_hint, :key => "Z")]), false]], SpeakCapture.log
  end

  test "a duel with no rule says no rules, and no key for a hand that is closed" do
    PokeTetra::Scene.new.pbStartScene(PokeTetra::Screen.new("Hilbert", 3, 2))
    assert_equal [[PokeAccess.sentences([t(:ttr_duel, :foe => "Hilbert"), t(:ttr_board, :rows => 2, :cols => 3)]),
                   false]], SpeakCapture.log
  end

  test "each flag the duel switches on has its words, in a fixed order" do
    flags = [[:@openHand, :ttr_rule_open], [:@sameWins, :ttr_rule_same], [:@wrapAround, :ttr_rule_wrap],
             [:@randomHand, :ttr_rule_random], [:@countUnplayedCards, :ttr_rule_count],
             [:@disableTypeBonus, :ttr_rule_notype]]
    battle = PokeTetra::Screen.new
    flags.each { |iv, _key| battle.instance_variable_set(iv, true) }
    assert_equal t(:ttr_rules, :list => flags.map { |_iv, key| t(key) }.join(", ")), PokeAccess::Tetra.rules_line(battle)
  end

  test "a rule left off is not said, and the flags that are on keep their order" do
    battle = PokeTetra::Screen.new
    battle.instance_variable_set(:@disableTypeBonus, true)
    battle.instance_variable_set(:@wrapAround, true)
    assert_equal t(:ttr_rules, :list => [t(:ttr_rule_wrap), t(:ttr_rule_notype)].join(", ")),
                 PokeAccess::Tetra.rules_line(battle)
  end

  test "the trade rules are said only where the hands are not the party's" do
    battle = PokeTetra::Screen.new
    battle.instance_variable_set(:@trade, 2)
    assert_nil PokeAccess::Tetra.rules_line(battle), "a party hand keeps its cards whatever the rule"
    with_use_party(false) do
      assert_equal t(:ttr_rules, :list => t(:ttr_rule_winall)), PokeAccess::Tetra.rules_line(battle)
      battle.instance_variable_set(:@trade, 1)
      assert_equal t(:ttr_rules, :list => t(:ttr_rule_direct)), PokeAccess::Tetra.rules_line(battle)
      battle.instance_variable_set(:@trade, 0)
      assert_nil PokeAccess::Tetra.rules_line(battle)
    end
  end

  test "the key for the rival's cards goes with the key hints" do
    battle = PokeTetra::Screen.new
    battle.openHand = true
    texts = vb_levels { PokeAccess::Tetra.open_hint(battle) }
    assert_equal [nil, t(:ttr_open_hint, :key => "Z"), t(:ttr_open_hint, :key => "Z")], texts
  end

  test "the key for the rival's cards is the one the player has bound to the game's A button" do
    battle = PokeTetra::Screen.new
    battle.openHand = true
    PokeAccess::Config.rebinds = { :a => 0x46 }
    assert_equal t(:ttr_open_hint, :key => PokeAccess::KeyHints.key(:a, "Z")), PokeAccess::Tetra.open_hint(battle)
    refute_equal t(:ttr_open_hint, :key => "Z"), PokeAccess::Tetra.open_hint(battle)
  end

  test "the blocked squares are named in board order, one or several, and no blocks say nothing" do
    scene = duel
    scene.pbPutBlockCards([6, 1, 15])
    scene.pbPutBlockCards([5])
    scene.pbPutBlockCards([])
    several = "#{cell_pos(1, 2)}; #{cell_pos(2, 3)}; #{cell_pos(4, 4)}"
    assert_equal [[t(:ttr_blocks, :n => 3, :list => several), false], [t(:ttr_blocks, :n => 1, :list => cell_pos(2, 2)), false]],
                 SpeakCapture.log
    refute_equal t(:ttr_blocks, :n => 1, :list => "x"), t(:ttr_blocks, :n => 2, :list => "x")
  end

  test "the lines the help window is given are read as dialogue" do
    scene = PokeTetra::Scene.new
    scene.pbDisplay("Choosing the starting player...")
    scene.pbDisplayPaused("Hilbert won against Ethan.")
    assert_equal [["Choosing the starting player...", false], ["Hilbert won against Ethan.", false]], SpeakCapture.log
  end

  test "the hand picker reads the card its raised sprite stands for, through the hand's slots, queued at first" do
    scene = duel(:mine => [11, 22, 33], :slots => [2, 0])
    scene.pbPlayerChooseCard(2) do
      raise_card(scene, "player", 2)
      frame
    end
    assert_equal [[card_line(33), false]], SpeakCapture.log
  end

  test "moving over the hand reads each card, cutting in, and a frame on the same card says nothing" do
    scene = duel
    scene.pbPlayerChooseCard(3) do
      [0, 1, 1, 2, 0].each do |slot|
        raise_card(scene, "player", slot)
        frame
      end
    end
    assert_equal [[card_line(11), false], [card_line(22), true], [card_line(33), true], [card_line(11), true]],
                 SpeakCapture.log
  end

  test "a hand with no card raised says nothing, and nor does one that cannot be read" do
    scene = duel
    scene.pbPlayerChooseCard(3) { frame }
    broken = duel
    broken.instance_variable_set(:@cardIndexes, nil)
    broken.pbPlayerChooseCard(3) { frame }
    assert_nothing_spoken
  end

  test "a raised card whose slot holds no species is not read" do
    scene = duel
    scene.instance_variable_get(:@sprites)["player9"] = Pic.new(0, 0, 4, true, nil)
    scene.instance_variable_set(:@cardIndexes, [9])
    scene.pbPlayerChooseCard(1) { frame }
    assert_nothing_spoken
  end

  test "a sprite the game has disposed is no raised card" do
    scene = duel
    scene.instance_variable_get(:@sprites)["player0"] = DeadPic.new
    scene.pbPlayerChooseCard(3) do
      raise_card(scene, "player", 1)
      frame
    end
    assert_equal [[card_line(22), false]], SpeakCapture.log
  end

  test "a hand card the game cannot build is read by its species alone" do
    scene = duel(:mine => [11, 22, 33])
    scene.pbPlayerChooseCard(3) do
      raise_card(scene, "player", 1)
      with_no_card_class { frame }
    end
    assert_equal [[sp_name(22), false]], SpeakCapture.log
  end

  test "the hand is read only while the picker runs" do
    scene = duel
    scene.pbPlayerChooseCard(3) { raise_card(scene, "player", 0) }
    raise_card(scene, "player", 1)
    frame
    assert_nothing_spoken
  end

  test "the rival's hand reads their card at the cursor, and a place past their last card as no card" do
    scene = duel(:foes => [44, 55])
    scene.pbViewOpponentCards(3) do
      raise_card(scene, "opponent", 1)
      frame
      raise_card(scene, "opponent", nil)
      frame
    end
    assert_equal [[card_line(55), false], [t(:triad_no_card), true]], SpeakCapture.log
  end

  test "the rival's hand says nothing of a viewer whose cards cannot be read" do
    scene = duel
    scene.instance_variable_set(:@opponentCardIndexes, nil)
    scene.pbViewOpponentCards(3) { frame }
    assert_nothing_spoken
  end

  test "coming back from the rival's hand reads the hand's first card again, cutting in, every time" do
    scene = duel
    scene.pbPlayerChooseCard(3) do
      raise_card(scene, "player", 0)
      frame
      2.times do
        scene.pbViewOpponentCards(3) do
          raise_card(scene, "opponent", 0)
          frame
        end
        frame
      end
    end
    assert_equal [[card_line(11), false], [card_line(44), false], [card_line(11), true], [card_line(44), false],
                  [card_line(11), true]], SpeakCapture.log
  end

  test "the hand's cursor is not read again for each frame the rival's hand is open" do
    scene = duel
    scene.pbPlayerChooseCard(3) do
      raise_card(scene, "player", 1)
      frame
      SpeakCapture.clear
      scene.pbViewOpponentCards(3) do
        raise_card(scene, "opponent", 1)
        3.times { frame }
      end
    end
    assert_equal [[card_line(55), false]], SpeakCapture.log
  end

  test "the board placer reads the square the card being placed sits on, queued at first" do
    scene = duel
    scene.pbPlayerPlaceCard(card(11), 0) do
      put_on_board(scene, 0, 0, 0)
      frame
      put_on_board(scene, 0, 2, 1)
      frame
      put_on_board(scene, 0, 2, 1)
      frame
    end
    assert_equal [[cell(1, 1, t(:triad_free)), false], [cell(2, 3, t(:triad_free)), true]], SpeakCapture.log
  end

  test "a square holding a card says whose it is and the card, and a block says it is blocked" do
    battle = PokeTetra::Screen.new
    take(battle, 1, 0, 1, 4)
    take(battle, 2, 0, 2, 33)
    battle.getPanel(3, 0).owner = -1
    scene = duel(:battle => battle)
    scene.pbPlayerPlaceCard(card(11), 0) do
      [[1, 0], [2, 0], [3, 0]].each do |x, y|
        put_on_board(scene, 0, x, y)
        frame
      end
    end
    assert_equal [[cell(1, 2, t(:triad_yours), card_line(4)), false], [cell(1, 3, t(:triad_theirs), card_line(33)), true],
                  [cell(1, 4, t(:ttr_blocked)), true]], SpeakCapture.log
  end

  test "a taken square with no card on it still says whose it is" do
    battle = PokeTetra::Screen.new
    battle.getPanel(0, 1).owner = 2
    scene = duel(:battle => battle)
    scene.pbPlayerPlaceCard(card(11), 0) do
      put_on_board(scene, 0, 0, 1)
      frame
    end
    assert_equal [[cell(2, 1, t(:triad_theirs)), false]], SpeakCapture.log
  end

  test "a placer with no card raised, or one standing off the board on any side, says nothing" do
    scene = duel
    scene.pbPlayerPlaceCard(card(11), 0) { frame }
    scene.pbPlayerPlaceCard(card(11), 0) do
      [[9, 9], [4, 0], [-1, 0], [0, 4], [0, -1]].each do |x, y|
        put_on_board(scene, 0, x, y)
        frame
      end
    end
    assert_nothing_spoken
  end

  test "the squares on every edge of the board are read" do
    scene = duel
    scene.pbPlayerPlaceCard(card(11), 0) do
      [[3, 0], [0, 3], [3, 3]].each do |x, y|
        put_on_board(scene, 0, x, y)
        frame
      end
    end
    free = t(:triad_free)
    assert_equal [[cell(1, 4, free), false], [cell(4, 1, free), true], [cell(4, 4, free), true]], SpeakCapture.log
  end

  test "confirming on a taken square says it is occupied, cutting in, and hands the game its own answer" do
    battle = PokeTetra::Screen.new
    battle.getPanel(1, 1).owner = 1
    assert_equal true, battle.isOccupied?(1, 1)
    assert_equal [[t(:ttr_occupied), true]], SpeakCapture.log
  end

  test "confirming on a free square says nothing, and hands the game its own answer" do
    battle = PokeTetra::Screen.new
    battle.getPanel(1, 1).owner = 1
    assert_equal false, battle.isOccupied?(0, 0)
    assert_nothing_spoken
  end

  test "reading the squares of the board never says the taken-square warning" do
    battle = PokeTetra::Screen.new
    take(battle, 1, 1, 1, 4)
    scene = duel(:battle => battle)
    scene.pbPlayerPlaceCard(card(11), 0) do
      put_on_board(scene, 0, 1, 1)
      frame
    end
    refute_spoken(/#{Regexp.escape(t(:ttr_occupied))}/)
  end

  test "the player's move names the card and its square, then the squares it flipped, then the score" do
    battle = PokeTetra::Screen.new
    scene = duel(:battle => battle, :mine => [11, 22], :foes => [44])
    take(battle, 0, 0, 2, 44)
    scene.pbEndOpponentPlaceCard([0, 0], 0)
    SpeakCapture.clear
    take(battle, 1, 0, 1, 11)
    battle.getPanel(0, 0).owner = 1
    scene.pbEndPlaceCard([1, 0], 0)
    flipped = t(:triad_captures, :list => "#{cell_pos(1, 1)}, #{sp_name(44)}")
    played = t(:ttr_you_play, :card => sp_name(11), :row => 1, :col => 2)
    assert_equal [[PokeAccess.sentences([played, flipped]), true], [t(:triad_score, :you => 2, :foe => 0), false]],
                 SpeakCapture.log
  end

  test "the rival's move is queued with the card in full, then the score, and the first move flips nothing" do
    battle = PokeTetra::Screen.new
    scene = duel(:battle => battle, :foes => [44, 55])
    take(battle, 2, 1, 2, 44)
    scene.pbEndOpponentPlaceCard([2, 1], 0)
    played = t(:triad_foe_plays, :card => card_line(44), :row => 2, :col => 3)
    assert_equal [[played, false], [t(:triad_score, :you => 0, :foe => 1), false]], SpeakCapture.log
  end

  test "a move that flips several squares names each, and only the squares that changed hands" do
    battle = PokeTetra::Screen.new
    scene = duel(:battle => battle, :mine => [11, 22, 33], :foes => [44, 55])
    take(battle, 0, 0, 1, 11)
    take(battle, 1, 0, 2, 44)
    take(battle, 2, 0, 1, 33)
    scene.pbEndPlaceCard([0, 0], 0)
    SpeakCapture.clear
    take(battle, 3, 0, 2, 55)
    battle.getPanel(0, 0).owner = 2
    battle.getPanel(2, 0).owner = 2
    scene.pbEndOpponentPlaceCard([3, 0], 0)
    flipped = t(:triad_captures, :list => "#{cell_pos(1, 1)}, #{sp_name(11)}; #{cell_pos(1, 3)}, #{sp_name(33)}")
    played = t(:triad_foe_plays, :card => card_line(55), :row => 1, :col => 4)
    assert_equal [[PokeAccess.sentences([played, flipped]), false], [t(:triad_score, :you => 0, :foe => 4), false]],
                 SpeakCapture.log
  end

  test "a move whose square cannot be read says nothing, and the next one still tells what it flipped" do
    battle = PokeTetra::Screen.new
    scene = duel(:battle => battle, :mine => [11, 22], :foes => [44])
    scene.pbEndPlaceCard(nil, 0)
    assert_equal [[t(:triad_score, :you => 0, :foe => 0), false]], SpeakCapture.log
    take(battle, 0, 0, 2, 44)
    scene.pbEndOpponentPlaceCard([0, 0], 0)
    SpeakCapture.clear
    take(battle, 1, 0, 1, 22)
    battle.getPanel(0, 0).owner = 1
    scene.pbEndPlaceCard([1, 0], 0)
    assert_match(/#{Regexp.escape(cell_pos(1, 1))}, #{Regexp.escape(sp_name(44))}/, SpeakCapture.lines.first)
  end

  test "the score is said each time it changes and never twice in a row" do
    battle = PokeTetra::Screen.new
    scene = duel(:battle => battle)
    scene.pbUpdateScore
    scene.pbUpdateScore
    battle.getPanel(0, 0).owner = 1
    scene.pbUpdateScore
    battle.getPanel(1, 0).owner = 2
    scene.pbUpdateScore
    assert_equal [[t(:triad_score, :you => 0, :foe => 0), false], [t(:triad_score, :you => 1, :foe => 0), false],
                  [t(:triad_score, :you => 1, :foe => 1), false]], SpeakCapture.log
  end

  test "the cards left in hand count toward the score under the countunplayed rule" do
    battle = PokeTetra::Screen.new
    battle.countUnplayedCards = true
    scene = duel(:battle => battle, :mine => [11, 22, 33], :foes => [44, 55])
    battle.getPanel(0, 0).owner = 1
    scene.pbUpdateScore
    assert_equal [[t(:triad_score, :you => 4, :foe => 2), false]], SpeakCapture.log
  end

  test "a duel opened again on a scene reads its first score, though it reads as the last one did" do
    battle = PokeTetra::Screen.new
    scene = duel(:battle => battle)
    scene.pbUpdateScore
    scene.pbStartScene(battle)
    SpeakCapture.clear
    scene.pbUpdateScore
    assert_equal [[t(:triad_score, :you => 0, :foe => 0), false]], SpeakCapture.log
  end

  test "the info key holds the score and the board, row by row, by what each square holds" do
    battle = PokeTetra::Screen.new("Hilbert", 2, 2)
    take(battle, 0, 0, 1, 4)
    take(battle, 1, 0, 2, 33)
    battle.getPanel(0, 1).owner = -1
    scene = duel(:battle => battle)
    scene.pbUpdateScore
    first = "#{sp_name(4)} #{t(:triad_yours)}, #{sp_name(33)} #{t(:triad_theirs)}"
    second = "#{t(:ttr_blocked)}, #{t(:triad_free)}"
    assert_equal PokeAccess.sentences([t(:triad_score, :you => 1, :foe => 1), t(:ttr_row, :row => 1, :cells => first),
                                       t(:ttr_row, :row => 2, :cells => second)]), PokeAccess::Info.info_text
  end

  test "the board leaves the info key when the duel closes" do
    scene = duel
    scene.pbUpdateScore
    refute_nil PokeAccess::Info.info_text
    scene.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "the deck chooser reads its prompt and the cards taken so far, then each preview card once" do
    scene = duel(:help => "Choose 6 cards to use for this duel.")
    scene.pbChooseCard([[4, 2], [7, 1]]) do
      frame
      card(4).createBitmap(1, nil)
      card(4).createBitmap(1, nil)
      take_cards(scene, 1)
      frame
      card(4).createBitmap(1, nil)
      card(7).createBitmap(1, nil)
    end
    assert_equal [["Choose 6 cards to use for this duel.", false], [t(:ttr_chosen, :n => 0, :max => 6), false],
                  [card_line(4), false], [t(:ttr_chosen, :n => 1, :max => 6), false], [card_line(7), false]],
                 SpeakCapture.log
  end

  test "taking a card back is counted, and the prompt that follows the last card is read" do
    scene = duel(:help => "Choose 6 cards to use for this duel.")
    scene.pbChooseCard([[4, 2]]) do
      take_cards(scene, 2)
      frame
      take_cards(scene, 1)
      frame
      take_cards(scene, 6)
      scene.instance_variable_get(:@sprites)["helpwindow"].text = "6 cards have been chosen."
      frame
    end
    assert_equal [t(:ttr_chosen, :n => 2, :max => 6), t(:ttr_chosen, :n => 1, :max => 6),
                  t(:ttr_chosen, :n => 6, :max => 6)], SpeakCapture.lines.reject { |l| l =~ /Choose|chosen\./ }
    assert_includes SpeakCapture.lines, "6 cards have been chosen."
  end

  test "the deck chooser counts only the sprites that show a card, a missing or disposed one not among them" do
    scene = duel
    sprites = scene.instance_variable_get(:@sprites)
    take_cards(scene, 3)
    sprites.delete("player4")
    sprites["player5"] = DeadPic.new
    taken, text = PokeAccess::Tetra.chosen_entry(scene)
    assert_equal [3, t(:ttr_chosen, :n => 3, :max => 6)], [taken, text.call]
  end

  test "a card drawn outside the deck chooser says nothing, before it opens or after it closes" do
    scene = duel
    card(4).createBitmap(1, nil)
    scene.pbChooseCard([[4, 1]]) { card(7).createBitmap(1, nil) }
    card(9).createBitmap(1, nil)
    assert_equal [[card_line(7), false]], SpeakCapture.log
  end

  test "opening the deck chooser again reads its first card again" do
    scene = duel
    2.times { scene.pbChooseCard([[4, 1]]) { card(4).createBitmap(1, nil) } }
    assert_equal [[card_line(4), false]] * 2, SpeakCapture.log
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  def frame; PokeAccess::Frame.run_pollers; end

  # The species a test names by number, as the engine has them: the number itself, or a symbol.
  def sp(n); ENGINE == :gamedata ? :"S#{n}" : n; end

  def sp_name(n); PokeAccess::Data.species_name(sp(n)); end

  def card(n); PokeTetra::Card.new(sp(n)); end

  # A card's line as the picker reads it, the sides numbered from the stand-in's own.
  def card_line(n)
    c = card(n)
    type = t(:mv_type, :t => PokeAccess::Data.type_name(c.type))
    t(:triad_card, :name => "#{sp_name(n)}, #{type}", :n => c.north, :e => c.east, :s => c.south, :w => c.west)
  end

  # A board square's place, one-based, as the reader names it.
  def cell_pos(row, col); t(:triad_cell, :row => row, :col => col); end

  # A square's line: its place, then each of rest.
  def cell(row, col, *rest); [cell_pos(row, col), *rest].join(", "); end

  # A duel scene: a hand and the rival's, one sprite per card, none raised. slots is the order of the hand's cards over
  # its sprites; help the text of the help window; battle the screen the scene was given.
  def duel(opts = {})
    mine = (opts[:mine] || [11, 22, 33]).map { |n| sp(n) }
    foes = (opts[:foes] || [44, 55]).map { |n| sp(n) }
    sprites = {}
    [mine.length, PokeTetra::HAND_SIZE].max.times { |i| sprites["player#{i}"] = Pic.new(300, 34 + 48 * i, 2, true, nil) }
    foes.each_index { |i| sprites["opponent#{i}"] = Pic.new(2, 34 + 48 * i, 2, true, nil) }
    sprites["helpwindow"] = Box.new(opts[:help].to_s)
    PokeTetra::Scene.new(:@battle => opts[:battle] || PokeTetra::Screen.new, :@sprites => sprites,
                         :@cardIndexes => opts[:slots] || (0...mine.length).to_a, :@playerCards => mine,
                         :@opponentCardIndexes => (0...foes.length).to_a, :@opponentCards => foes)
  end

  # Raises one hand's card sprite to the cursor's z and drops the rest, as the loops do; none for a nil slot.
  def raise_card(scene, prefix, slot)
    sprites = scene.instance_variable_get(:@sprites)
    sprites.each { |key, pic| pic.z = 2 if key =~ /\A#{prefix}\d+\z/ && pic.respond_to?(:z=) }
    sprites["#{prefix}#{slot}"].z = 4 if slot
  end

  # Moves the sprite of a hand slot onto a board square, raised, as the placer does.
  def put_on_board(scene, slot, x, y)
    pic = scene.instance_variable_get(:@sprites)["player#{slot}"]
    pic.x = PokeTetra::Scene::FIELD_BASE_X + x * PokeTetra::Card::WIDTH
    pic.y = PokeTetra::Scene::FIELD_BASE_Y + y * PokeTetra::Card::HEIGHT
    pic.z = 4
  end

  # Sets a board square's owner and the card on it.
  def take(battle, x, y, owner, n)
    battle.getPanel(x, y).owner = owner
    battle.getPanel(x, y).card = card(n)
  end

  # Shows n of the hand's sprites as cards the chooser has taken, as its loop leaves them.
  def take_cards(scene, n)
    sprites = scene.instance_variable_get(:@sprites)
    PokeTetra::HAND_SIZE.times do |i|
      sprites["player#{i}"].visible = i < n
      sprites["player#{i}"].bitmap = i < n ? :card : nil
    end
  end

  # Runs the block with the game's card class gone, as a copy that renamed it leaves the reader.
  def with_no_card_class
    klass = PokeTetra.send(:remove_const, :Card)
    yield
  ensure
    PokeTetra.const_set(:Card, klass)
  end

  # Runs the block with USE_PARTY as given, the stand-in's own put back after.
  def with_use_party(value)
    PokeTetra.send(:remove_const, :USE_PARTY)
    PokeTetra.const_set(:USE_PARTY, value)
    yield
  ensure
    PokeTetra.send(:remove_const, :USE_PARTY)
    PokeTetra.const_set(:USE_PARTY, true)
  end
end
