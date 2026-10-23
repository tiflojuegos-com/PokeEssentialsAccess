# Minigame state said as it changes: Voltorb Flip's cursor, level, mode and coins; Triple Triad's score, the prompts
# it writes into its help window and its deck rows; the mining wall's squares, finds and blows left.

# The mining cursor as the game draws it (MiningGameCursor): its square and the tool in hand, 0 the pick and 1 the
# hammer. MinigameStateTest binds to it the hooks core/field/minigames.rb declares on the class.
class MiningGameCursor
  attr_accessor :position, :mode
  def initialize(position = 0, mode = 0); @position = position; @mode = mode; end
  def update; end
end

# The mining wall as the game runs it (MiningGameScene): 13 x 10 squares under three layers of rock, the squares that
# hide part of an item or iron, the items won so far, the cursor and the crack bar. Its scene start and end and the
# blow (pbHit) carry the hooks MinigameStateTest binds; the test digs the squares a blow uncovers itself.
class MiningGameScene
  # A square of the wall (the game's MiningGameTile): the rock left on it.
  Tile = Struct.new(:layer)
  # The crack bar over the wall (the game's MiningGameCounter): the hits taken so far.
  Crack = Struct.new(:hits)
  # The game's item table, rows [item, odds, x, y, width, height, pattern]: one item two squares wide.
  ITEMS = [[:POTION, 1, 0, 0, 2, 1, [1, 1]]]

  attr_accessor :itemswon, :items
  def initialize(items, iron, cursor, hits)
    @items_at = items
    @iron_at = iron
    @items = []
    @itemswon = []
    @sprites = { "cursor" => cursor, "crack" => Crack.new(hits) }
    130.times { |i| @sprites["tile#{i}"] = Tile.new(3) }
  end

  def pbStartScene; end
  def pbEndScene; end
  def pbHit; end
  def pbIsItemThere?(pos); @items_at.include?(pos); end
  def pbIsIronThere?(pos); @iron_at.include?(pos); end

  # Leaves the given rock on a square, none by default.
  def dig(pos, rock = 0); @sprites["tile#{pos}"].layer = rock; end
end

class MinigameStateTest < PokeAccessTest
  Minigames = PokeAccess::Minigames
  Triad = PokeAccess::TripleTriad
  # Voltorb Flip card values in reading order: row 1 adds up to 7 with one Voltorb, column 1 to 5 with one, row 2 and
  # column 2 to 8 with none.
  VF_VALUES = [1, 2, 3, 0, 1,
               1, 3, 1, 1, 2,
               0, 1, 2, 1, 1,
               2, 1, 0, 1, 3,
               1, 1, 1, 2, 0].freeze
  # Triple Triad's help window: the text the game writes into it.
  HelpWindow = Struct.new(:text)
  # The hook declarations of core/field/minigames.rb on the mining cursor and wall, each through the end of its block.
  MINE_HOOKS = /^PokeAccess::Hooks\.\w+\("MiningGame(?:Cursor|Scene)".*?(?:\}\n|^end\n)/m

  # The duel under a Triple Triad scene: a board of squares each with its card's owner (0 none, 1 the player,
  # 2 the rival), and whether the cards still in hand count, as the "countunplayed" rule has it.
  class TriadDuel
    Square = Struct.new(:owner)
    attr_reader :width, :height, :board
    def initialize(owners, width, unplayed = false)
      @width = width
      @height = owners.length / width
      @board = owners.map { |o| Square.new(o) }
      @unplayed = unplayed
    end

    def countUnplayedCards; @unplayed; end
  end

  # The deck selector's list of cards (the game's Window_CommandPokemonEx): its rows as the game writes them.
  class DeckList
    attr_accessor :index
    def initialize(rows); @commands = rows; @index = 0; end
  end

  # Binds, once, the hooks core/field/minigames.rb declares on MiningGameCursor and MiningGameScene: the mod declared
  # them as it loaded, before the stand-ins existed. The source comes through the harness, so a mutant of it is the
  # one bound.
  def self.bind_hooks
    @bound ||= begin
      path = File.join(Harness::ROOT, "core", "field", "minigames.rb")
      src = Harness.source(path)
      src.scan(MINE_HOOKS) { eval($&, TOPLEVEL_BINDING, path, src[0, $~.begin(0)].count("\n") + 1) }
      true
    end
  end
  private_class_method :bind_hooks

  # Binds the hooks; the screen the hooks last noted, which the stand-ins' hooked methods change, is put back after
  # each test.
  def setup
    super
    self.class.send(:bind_hooks)
    @screen = PokeAccess::Hooks.screen
  end

  def teardown
    PokeAccess::Hooks.note_screen(@screen)
    super
  end

  test "Voltorb Flip says the level, the square, the counts of its row and column and the board's keys on arrival" do
    Minigames.voltorb_flip(vf_scene(:level => 4))
    said = [t(:mg_level, :n => 4), t(:mg_rowcol, :row => 1, :col => 1), t(:mg_hidden), vf_line(:mg_row, 7, 1),
            vf_line(:mg_col, 5, 1)].join(", ")
    assert_equal [[PokeAccess::Verbosity.with_hint(said, vf_keys), true]], SpeakCapture.log
  end

  test "Voltorb Flip on arrival says the coins held, and the info key gives the level and the coins held and won" do
    scene = vf_scene(:level => 2)
    scene.instance_variable_set(:@points, 6)
    with_coins(120) { Minigames.voltorb_flip(scene) }
    assert_match(/\A#{Regexp.escape("#{t(:mg_level, :n => 2)}, #{t(:mg_coins, :n => 120)}, #{t(:mg_rowcol, :row => 1, :col => 1)}")}/,
                 SpeakCapture.lines[0])
    head = [t(:mg_level, :n => 2), t(:mg_coins, :n => 120), t(:mg_vf_earned, :n => 6)].join(", ")
    assert_match(/\A#{Regexp.escape(head)}\. #{Regexp.escape(t(:mg_board_row, :n => 1, :cells => ([t(:mg_hidden)] * 5).join(", "), :sum => 7, :voltorbs => 1))}/,
                 PokeAccess::Info.info_text)
  end

  test "a Voltorb Flip game that is quitting says nothing: its Coin Case filled, or it cashed out to no coins won" do
    scene = vf_scene
    Minigames.voltorb_flip(scene)
    SpeakCapture.clear
    scene.instance_variable_set(:@points, 5)
    scene.instance_variable_set(:@quit, true)
    Minigames.voltorb_flip(scene)
    full = vf_scene(:level => 6)
    full.instance_variable_set(:@quit, true)
    Minigames.voltorb_flip(full)
    assert_nothing_spoken
  end

  test "the board turned face up says every card row by row and the key that goes on, queued, and the info key gives it" do
    scene = vf_scene
    scene.instance_variable_get(:@squares)[3][3] = true
    Minigames.vf_reveal(scene)
    rows = VF_VALUES.each_slice(5).each_with_index.map do |cards, r|
      sum = cards.inject(0) { |a, v| a + v }
      t(:mg_board_row, :n => r + 1, :cells => cards.map { |v| v == 0 ? t(:mg_voltorb) : v.to_s }.join(", "),
                       :sum => sum, :voltorbs => cards.count(0))
    end
    hint = t(:title_press, :key => "C")
    assert_equal [[PokeAccess::Verbosity.with_hint(rows.join(". "), hint), false]], SpeakCapture.log
    assert_equal "#{t(:mg_level, :n => 1)}, #{t(:mg_vf_earned, :n => 0)}. #{rows.join('. ')}", PokeAccess::Info.info_text
  end

  test "a Voltorb Flip board turned face up with no cards says nothing" do
    Minigames.vf_reveal(World.stub_scene(:@squares => [0, 0, 0, false]))
    assert_nothing_spoken
  end

  test "the info key over the map gives the minigame's line while its screen is up, and nothing once it closed" do
    viewport = Struct.new(:disposed).new(false)
    def viewport.disposed?; disposed; end
    scene = vf_scene
    scene.instance_variable_set(:@viewport, viewport)
    Minigames.voltorb_flip(scene)
    PokeAccess::Info.set_info(:map, nil)
    assert_equal Minigames.vf_info(scene), PokeAccess::Info.info_text, "a pbWait reset the key to the map"
    viewport.disposed = true
    assert_nil Minigames.board, "its viewport disposed"
    Minigames.unpublish
    assert_nil Minigames.board, "its screen closed"
  end

  test "a move on the Voltorb Flip board says the new square and the counts of the line it enters only" do
    moves = { [1, 0] => [t(:mg_rowcol, :row => 1, :col => 2), t(:mg_hidden), vf_line(:mg_col, 8, 0)],
              [0, 1] => [t(:mg_rowcol, :row => 2, :col => 1), t(:mg_hidden), vf_line(:mg_row, 8, 0)] }
    moves.each do |(col, row), parts|
      scene = vf_scene
      Minigames.voltorb_flip(scene)
      SpeakCapture.clear
      scene.instance_variable_set(:@index, [col, row])
      Minigames.voltorb_flip(scene)
      assert_equal [[parts.join(", "), true]], SpeakCapture.log, "a move to column #{col + 1}, row #{row + 1}"
    end
  end

  test "a Voltorb Flip frame with nothing changed says nothing" do
    scene = vf_scene
    Minigames.voltorb_flip(scene)
    SpeakCapture.clear
    Minigames.voltorb_flip(scene)
    assert_nothing_spoken
  end

  test "a Voltorb Flip card says its value once turned, Voltorb for a zero, and before that whether it is marked" do
    squares = vf_squares(VF_VALUES, [3, 6])
    marks = [nil, vf_mark(2, 1)]
    cards = { [3, 0] => t(:mg_voltorb), [1, 1] => "3", [2, 1] => t(:mg_marked), [0, 0] => t(:mg_hidden) }
    cards.each do |(col, row), said|
      assert_equal said, Minigames.vf_cell(squares, marks, col, row), "the card in column #{col + 1}, row #{row + 1}"
    end
  end

  test "a Voltorb Flip board with no card on a square says nothing for it" do
    assert_equal "", Minigames.vf_cell([nil] * 25, [], 0, 0)
  end

  test "Voltorb Flip says the mode as it toggles" do
    scene = vf_scene
    Minigames.voltorb_flip(scene)
    { 64 => t(:mg_mode_mark), 0 => t(:mg_mode_normal) }.each do |mode, said|
      SpeakCapture.clear
      scene.instance_variable_set(:@cursor, [["cursor", 128, 0, mode, 0, 64, 64]])
      Minigames.voltorb_flip(scene)
      assert_equal [["#{said}, #{t(:mg_rowcol, :row => 1, :col => 1)}, #{t(:mg_hidden)}", true]], SpeakCapture.log,
                   "the cursor's mode #{mode}"
    end
  end

  test "a turned Voltorb Flip card that changes the coins won says them first, as won" do
    scene = vf_scene
    Minigames.voltorb_flip(scene)
    SpeakCapture.clear
    scene.instance_variable_get(:@squares)[0][3] = true
    scene.instance_variable_set(:@points, 1)
    Minigames.voltorb_flip(scene)
    assert_equal [["#{t(:mg_vf_earned, :n => 1)}, #{t(:mg_rowcol, :row => 1, :col => 1)}, 1", true]], SpeakCapture.log
  end

  test "a new Voltorb Flip board says its level, the square and both counts again" do
    scene = vf_scene(:level => 1)
    Minigames.voltorb_flip(scene)
    scene.instance_variable_set(:@index, [1, 0])
    Minigames.voltorb_flip(scene)
    SpeakCapture.clear
    scene.instance_variable_set(:@squares, vf_squares(VF_VALUES))
    scene.instance_variable_set(:@index, [0, 0])
    scene.instance_variable_set(:@level, 2)
    Minigames.voltorb_flip(scene)
    assert_equal [[t(:mg_level, :n => 2), t(:mg_rowcol, :row => 1, :col => 1), t(:mg_hidden), vf_line(:mg_row, 7, 1),
                   vf_line(:mg_col, 5, 1)].join(", ")],
                 SpeakCapture.lines
  end

  test "a Voltorb Flip scene without its cursor says nothing" do
    scene = vf_scene
    scene.instance_variable_set(:@index, nil)
    Minigames.voltorb_flip(scene)
    assert_nothing_spoken
  end

  test "Triple Triad says the score counted off the board, interrupting" do
    Triad.score(triad_scene(TriadDuel.new([1, 2, 0, 1, 0, 0, 0, 0, 0], 3)))
    assert_equal [[t(:triad_score, :you => 2, :foe => 1), true]], SpeakCapture.log
  end

  test "a Triple Triad count that has not changed says nothing" do
    scene = triad_scene(TriadDuel.new([1, 2, 0, 1, 0, 0, 0, 0, 0], 3))
    Triad.score(scene)
    SpeakCapture.clear
    Triad.score(scene)
    assert_nothing_spoken
  end

  test "Triple Triad names the squares a move turned over before the score, not the square played" do
    duel = TriadDuel.new([1, 2, 0, 1, 0, 2, 0, 0, 0], 3)
    scene = triad_scene(duel)
    Triad.score(scene)
    SpeakCapture.clear
    [[1, 1], [2, 1], [5, 1]].each { |i, owner| duel.board[i].owner = owner }
    Triad.score(scene)
    turned = [t(:triad_cell, :row => 1, :col => 2), t(:triad_cell, :row => 2, :col => 3)].join("; ")
    assert_equal ["#{t(:triad_captures, :list => turned)}. #{t(:triad_score, :you => 5, :foe => 0)}"],
                 SpeakCapture.lines
  end

  test "Triple Triad names the squares the rival's move takes from the player too" do
    duel = TriadDuel.new([1, 1, 0, 0, 0, 0, 0, 0, 0], 3)
    scene = triad_scene(duel)
    Triad.score(scene)
    SpeakCapture.clear
    [[0, 2], [1, 2], [2, 2]].each { |i, owner| duel.board[i].owner = owner }
    Triad.score(scene)
    taken = [t(:triad_cell, :row => 1, :col => 1), t(:triad_cell, :row => 1, :col => 2)].join("; ")
    assert_equal ["#{t(:triad_captures, :list => taken)}. #{t(:triad_score, :you => 0, :foe => 3)}"],
                 SpeakCapture.lines
  end

  test "a Triple Triad board cleared for a new game names no captures, only the score" do
    duel = TriadDuel.new([1, 2, 1, 0, 0, 0, 0, 0, 0], 3)
    scene = triad_scene(duel)
    Triad.score(scene)
    SpeakCapture.clear
    duel.board.each { |square| square.owner = 0 }
    Triad.score(scene)
    assert_equal [t(:triad_score, :you => 0, :foe => 0)], SpeakCapture.lines
  end

  test "Triple Triad counts the cards still in hand under the countunplayed rule" do
    scene = triad_scene(TriadDuel.new([1, 2, 0, 1, 0, 0, 0, 0, 0], 3, true), [1, 2], [7])
    Triad.score(scene)
    assert_equal [t(:triad_score, :you => 4, :foe => 2)], SpeakCapture.lines
  end

  test "a Triple Triad duel that cannot tell its rule, its hands or its size counts what it can read" do
    owners = [1, 2, 0, 1, 0, 0, 0, 0, 0]
    no_rule = Struct.new(:width, :height, :board).new(3, 3, TriadDuel.new(owners, 3).board)
    no_size = Struct.new(:board).new(TriadDuel.new(owners, 3).board)
    unread = TriadDuel.new(owners, 3, true)
    cases = { "no countunplayed rule: the board alone" => [triad_scene(no_rule, [1, 2], [7]), 2, 1],
              "hands that cannot be read: the board alone" => [triad_scene(unread, nil, nil), 2, 1],
              "no board size: no squares" => [triad_scene(no_size), 0, 0] }
    cases.each do |what, (scene, you, foe)|
      SpeakCapture.clear
      Triad.score(scene)
      assert_equal [t(:triad_score, :you => you, :foe => foe)], SpeakCapture.lines, what
    end
  end

  test "the Triple Triad score after the rival's move is queued behind it" do
    duel = TriadDuel.new([0, 0, 0, 0, 0, 2, 0, 0, 0], 3)
    Triad.opponent_played(TriadCard.new(4), [2, 1])
    Triad.score(triad_scene(duel))
    card = t(:triad_card, :name => "#{PBSpecies.getName(4)}, #{t(:mv_type, :t => PBTypes.getName(1))}",
                          :n => 5, :e => 8, :s => 10, :w => 2)
    assert_equal [[t(:triad_foe_plays, :card => card, :row => 2, :col => 3), false],
                  [t(:triad_score, :you => 0, :foe => 1), false]],
                 SpeakCapture.log
  ensure
    Triad.score(Object.new)
  end

  test "a Triple Triad score after the one the rival's move queued interrupts again" do
    duel = TriadDuel.new([2, 0, 0, 0, 0, 0, 0, 0, 0], 3)
    scene = triad_scene(duel)
    Triad.opponent_played(TriadCard.new(4), [0, 0])
    Triad.score(scene)
    SpeakCapture.clear
    duel.board[4].owner = 1
    Triad.score(scene)
    assert_equal [[t(:triad_score, :you => 1, :foe => 1), true]], SpeakCapture.log
  ensure
    Triad.score(Object.new)
  end

  test "a Triple Triad rival's move without a card or a square says nothing, and the next score interrupts" do
    { "no card" => [Object.new, [2, 1]], "no square" => [TriadCard.new(4), nil] }.each do |what, (card, square)|
      SpeakCapture.clear
      Triad.opponent_played(card, square)
      Triad.score(triad_scene(TriadDuel.new([0, 0, 0, 0, 0, 2, 0, 0, 0], 3)))
      assert_equal [[t(:triad_score, :you => 0, :foe => 1), true]], SpeakCapture.log, what
    end
  ensure
    Triad.score(Object.new)
  end

  test "a Triple Triad scene with no duel says nothing" do
    Triad.score(Object.new)
    assert_nothing_spoken
  end

  test "Triple Triad reads, queued, the prompt the game writes straight into its help window" do
    scene = triad_help_scene("Elige 5 cartas para este duelo.")
    in_deck(scene) { Triad.poll }
    assert_equal [["Elige 5 cartas para este duelo.", false]], SpeakCapture.log
  end

  test "a Triple Triad prompt is read without the pause mark the game ends it with" do
    scene = triad_help_scene("Coloca la carta.\1")
    in_deck(scene) { Triad.poll }
    assert_equal ["Coloca la carta."], SpeakCapture.lines
  end

  test "a Triple Triad prompt is read once while it stays up, and the next one as it replaces it" do
    scene = triad_help_scene("Elige una carta.")
    in_deck(scene) do
      Triad.poll
      SpeakCapture.clear
      Triad.poll
      assert_nothing_spoken "the same prompt on the next frame"
      help_of(scene).text = "Elige una carta, o mira al rival con Z."
      Triad.poll
    end
    assert_equal ["Elige una carta, o mira al rival con Z."], SpeakCapture.lines
  end

  test "a Triple Triad prompt still up after the dialogue's half-second dedup is not read again" do
    scene = triad_help_scene("Mira las cartas del rival.")
    in_deck(scene) do
      Triad.poll
      SpeakCapture.clear
      a_second_later { Triad.poll }
    end
    assert_nothing_spoken
  end

  test "each Triple Triad loop that opens reads its prompt, even one the last loop showed" do
    scene = triad_help_scene("Elige 3 cartas para este duelo.")
    in_deck(scene) { Triad.poll }
    SpeakCapture.clear
    a_second_later { in_deck(scene) { Triad.poll } }
    assert_equal ["Elige 3 cartas para este duelo."], SpeakCapture.lines
  end

  test "an emptied Triple Triad help window says nothing" do
    { "" => "empty", "   " => "blank" }.each do |text, what|
      SpeakCapture.clear
      in_deck(triad_help_scene(text)) { Triad.poll }
      assert_nothing_spoken what
    end
  end

  test "a Triple Triad prompt the help window blanks for a moment and shows again is not read again" do
    scene = triad_help_scene("Elige una carta.")
    in_deck(scene) do
      Triad.poll
      help_of(scene).text = ""
      Triad.poll
      SpeakCapture.clear
      help_of(scene).text = "Elige una carta."
      a_second_later { Triad.poll }
    end
    assert_nothing_spoken
  end

  test "once its Triple Triad loop closes, a new line in the help window is not read" do
    scene = triad_help_scene("Elige 4 cartas para este duelo.")
    in_deck(scene) { Triad.poll }
    assert_equal ["Elige 4 cartas para este duelo."], SpeakCapture.lines, "read while the loop ran"
    SpeakCapture.clear
    help_of(scene).text = "El rival coloca una carta."
    Triad.poll
    assert_nothing_spoken "after it closes"
  end

  test "outside the Triple Triad deck selector, a deck row reads as the list writes it" do
    assert_equal "Bulbasaur x3", Triad.deck_row(DeckList.new(["Bulbasaur x3"]), 0)
  end

  test "in the Triple Triad deck selector, each row adds its card's type and four sides" do
    list = DeckList.new(["Bulbasaur x3", "Charmander x1"])
    rows = { 0 => ["Bulbasaur x3", t(:mv_type, :t => PBTypes.getName(1)),
                   t(:triad_sides, :n => 2, :e => 5, :s => 7, :w => 9)],
             1 => ["Charmander x1", t(:mv_type, :t => PBTypes.getName(2)),
                   t(:triad_sides, :n => 3, :e => 6, :s => 8, :w => 10)] }
    rows.each do |row, parts|
      list.index = row
      said = in_deck(Object.new, [[1, 3], [2, 1]]) { Triad.deck_row(list, row) }
      assert_equal parts.join(", "), said, "row #{row + 1}"
    end
  end

  test "in the Triple Triad deck selector, a row with no card behind it reads as the list writes it" do
    list = DeckList.new(["Bulbasaur x3", "Carta rara x1", "Salir"])
    rows = { 1 => ["Carta rara x1", "a row whose card cannot be drawn"],
             2 => ["Salir", "a row with no card in the storage"],
             5 => [nil, "a row past the list, where the list writes nothing"] }
    rows.each do |row, (said, what)|
      read = in_deck(Object.new, [[1, 3], [Object.new, 1]]) { Triad.deck_row(list, row) }
      said.nil? ? assert_nil(read, what) : assert_equal(said, read, what)
    end
  end

  test "once the Triple Triad deck selector closes, a row reads as the list writes it again" do
    list = DeckList.new(["Bulbasaur x3"])
    in_deck(Object.new, [[1, 3]]) { Triad.deck_row(list, 0) }
    assert_equal "Bulbasaur x3", Triad.deck_row(list, 0)
  end

  test "the mining cursor says its square, the rock left and the tool in hand, interrupting" do
    cursor = MiningGameCursor.new(0)
    with_mine(mine_scene(cursor)) { Minigames.mining_cursor(cursor) }
    assert_equal [["#{t(:mg_rowcol, :row => 1, :col => 1)}, #{t(:mg_rock, :n => 3)}, #{t(:mg_pick)}", true]],
                 SpeakCapture.log
  end

  test "a mining cursor move names the new square, and not the tool still in hand" do
    cursor = MiningGameCursor.new(0)
    with_mine(mine_scene(cursor)) do
      Minigames.mining_cursor(cursor)
      SpeakCapture.clear
      cursor.position = 14
      Minigames.mining_cursor(cursor)
    end
    assert_equal ["#{t(:mg_rowcol, :row => 2, :col => 2)}, #{t(:mg_rock, :n => 3)}"], SpeakCapture.lines
  end

  test "the mining cursor names the other tool as it is taken, with the blows that tool has left" do
    cursor = MiningGameCursor.new(0)
    with_mine(mine_scene(cursor, :hits => 12)) do
      Minigames.mining_cursor(cursor)
      { 1 => [t(:mg_hammer), 19], 0 => [t(:mg_pick), 37] }.each do |mode, (tool, left)|
        SpeakCapture.clear
        cursor.mode = mode
        Minigames.mining_cursor(cursor)
        assert_equal ["#{t(:mg_rowcol, :row => 1, :col => 1)}, #{t(:mg_rock, :n => 3)}, #{tool}, #{t(:mg_wall_left, :n => left)}"],
                     SpeakCapture.lines, tool
      end
    end
  end

  test "a mining cursor that stays put says nothing" do
    cursor = MiningGameCursor.new(0)
    with_mine(mine_scene(cursor)) do
      Minigames.mining_cursor(cursor)
      SpeakCapture.clear
      Minigames.mining_cursor(cursor)
    end
    assert_nothing_spoken
  end

  test "a dug-through mining square says what it shows: part of an item, iron, or nothing" do
    cursor = MiningGameCursor.new(0)
    scene = mine_scene(cursor, :items => [1], :iron => [2])
    [1, 2, 3].each { |pos| scene.dig(pos) }
    with_mine(scene) do
      Minigames.mining_cursor(cursor)
      { 1 => t(:mg_tile_item), 2 => t(:mg_tile_iron), 3 => t(:mg_tile_clear) }.each do |pos, shown|
        SpeakCapture.clear
        cursor.position = pos
        Minigames.mining_cursor(cursor)
        assert_equal ["#{t(:mg_rowcol, :row => 1, :col => pos + 1)}, #{shown}"], SpeakCapture.lines, "square #{pos}"
      end
    end
  end

  test "with no wall built, or no square under it, the mining cursor says its place and tool only" do
    cases = { "no wall" => [nil, 14, 2, 2],
              "past the wall's squares" => [mine_scene(MiningGameCursor.new(0)), 133, 11, 4] }
    cases.each do |what, (scene, pos, row, col)|
      SpeakCapture.clear
      with_mine(scene) { Minigames.mining_cursor(MiningGameCursor.new(pos, 1)) }
      assert_equal ["#{t(:mg_rowcol, :row => row, :col => col)}, #{t(:mg_hammer)}"], SpeakCapture.lines, what
    end
  end

  test "the mining cursor reads the wall's width from the game, in either spelling" do
    %w[BOARD_WIDTH BOARDWIDTH].each do |spelling|
      SpeakCapture.clear
      with_board_width(spelling, 7) { with_mine(nil) { Minigames.mining_cursor(MiningGameCursor.new(8)) } }
      assert_equal ["#{t(:mg_rowcol, :row => 2, :col => 2)}, #{t(:mg_pick)}"], SpeakCapture.lines, spelling
    end
  end

  test "while the mine is up its cursor says what each square shows, and once it ends only where it is" do
    cursor = MiningGameCursor.new(0)
    scene = mine_scene(cursor)
    scene.pbStartScene
    cursor.update
    assert_equal ["#{t(:mg_rowcol, :row => 1, :col => 1)}, #{t(:mg_rock, :n => 3)}, #{t(:mg_pick)}"],
                 SpeakCapture.lines, "while the mine is up"
    scene.pbEndScene
    SpeakCapture.clear
    cursor.position = 1
    cursor.update
    assert_equal [t(:mg_rowcol, :row => 1, :col => 2)], SpeakCapture.lines, "once it ended"
  ensure
    Minigames.mine_scene = nil
  end

  test "a blow says where part of an item came into sight besides the square under the cursor, then the blows left" do
    scene = mine_scene(MiningGameCursor.new(14), :items => [1, 2], :iron => [14], :hits => 6)
    scene.dig(14)
    scene.dig(2)
    scene.pbHit
    assert_equal [["#{t(:mg_item_at, :where => rowcol(1, 3))}, #{t(:mg_tile_iron)}", false],
                  [t(:mg_wall_left, :n => 43), false]],
                 SpeakCapture.log
  end

  test "a blow says where iron came into sight, and what was in sight before is not said again" do
    scene = mine_scene(MiningGameCursor.new(14), :items => [2], :iron => [13, 15])
    scene.dig(2)
    Minigames.mining_after_hit(scene)
    SpeakCapture.clear
    [13, 15].each { |pos| scene.dig(pos) }
    scene.dig(14, 1)
    Minigames.mining_after_hit(scene)
    assert_equal [["#{t(:mg_iron_at, :where => "#{rowcol(2, 1)}, #{rowcol(2, 3)}")}, #{t(:mg_rock, :n => 1)}", false]],
                 SpeakCapture.log
  end

  test "a blow that unearths an item names it before the square under the cursor, and not as part of one" do
    scene = mine_scene(MiningGameCursor.new(14), :items => [1, 2])
    scene.dig(1)
    scene.dig(2)
    scene.items = [[0, 1, 0, true]]
    scene.itemswon = [1]
    scene.pbHit
    assert_equal [[t(:mg_found, :name => PBItems.getName(1)), false], [t(:mg_rock, :n => 3), false]], SpeakCapture.log
  end

  test "a dug-through square of an item already dug out says so, one of an item still buried does not" do
    cursor = MiningGameCursor.new(0)
    scene = mine_scene(cursor, :items => [1, 2, 28])
    [1, 2, 28].each { |pos| scene.dig(pos) }
    scene.items = [[0, 1, 0, true], [0, 2, 2, false]]
    { 2 => t(:mg_tile_item_won), 28 => t(:mg_tile_item) }.each do |pos, shown|
      assert_equal shown, Minigames.mining_tile(scene, pos), "square #{pos}"
    end
  end

  test "the info key reads the wall: the cracks, where items not yet dug out and iron show, and the squares dug" do
    scene = mine_scene(MiningGameCursor.new(40), :items => [1, 2, 28], :iron => [30], :hits => 13)
    [1, 2, 28, 30, 31].each { |pos| scene.dig(pos) }
    scene.items = [[0, 1, 0, true]]
    Minigames.mining_after_hit(scene)
    want = [t(:mg_mine_cracks, :n => 13, :max => 49), t(:mg_item_at, :where => rowcol(3, 3)),
            t(:mg_iron_at, :where => rowcol(3, 5)), t(:mg_mine_dug, :n => 5)]
    assert_equal want.join(". "), PokeAccess::Info.info_text
  end

  test "a blow that uncovers nothing new says the square under the cursor only" do
    scene = mine_scene(MiningGameCursor.new(14), :items => [1, 2])
    scene.dig(2)
    Minigames.mining_after_hit(scene)
    SpeakCapture.clear
    scene.dig(14, 1)
    Minigames.mining_after_hit(scene)
    assert_equal [[t(:mg_rock, :n => 1), false]], SpeakCapture.log
  end

  test "a blow that uncovers nothing, the cursor off the wall's squares, says nothing" do
    Minigames.mining_after_hit(mine_scene(MiningGameCursor.new(140)))
    assert_nothing_spoken
  end

  test "a blow that unearths items names each one, queued" do
    scene = mine_scene(MiningGameCursor.new(0))
    scene.itemswon = [1, 50]
    Minigames.mining_hit(scene)
    found = [t(:mg_found, :name => PBItems.getName(1)), t(:mg_found, :name => PBItems.getName(50))]
    assert_equal [[found.join(". "), false]], SpeakCapture.log
  end

  test "items already named are not named again, only those won since" do
    scene = mine_scene(MiningGameCursor.new(0))
    scene.itemswon = [1]
    Minigames.mining_hit(scene)
    SpeakCapture.clear
    Minigames.mining_hit(scene)
    assert_nothing_spoken "the same items again"
    scene.itemswon = [1, 50]
    Minigames.mining_hit(scene)
    assert_equal [t(:mg_found, :name => PBItems.getName(50))], SpeakCapture.lines
  end

  test "a mining scene whose won items cannot be read finds nothing and says nothing" do
    scene = mine_scene(MiningGameCursor.new(0))
    scene.itemswon = 5
    Minigames.mining_hit(scene)
    assert_nothing_spoken
  end

  test "the mining wall says the blows left at each new block of cracks, queued" do
    scene = mine_scene(MiningGameCursor.new(0))
    { 6 => 43, 12 => 37 }.each do |hits, left|
      SpeakCapture.clear
      crack_of(scene).hits = hits
      Minigames.mining_wall(scene)
      assert_equal [[t(:mg_wall_left, :n => left), false]], SpeakCapture.log, "#{hits} hits"
    end
  end

  test "an untouched mining wall, and blows within a block already said, say nothing" do
    scene = mine_scene(MiningGameCursor.new(0))
    Minigames.mining_wall(scene)
    assert_nothing_spoken "no cracks yet"
    crack_of(scene).hits = 6
    Minigames.mining_wall(scene)
    SpeakCapture.clear
    crack_of(scene).hits = 11
    Minigames.mining_wall(scene)
    assert_nothing_spoken "the same block"
  end

  test "with the hammer in hand, the mining wall counts hammer blows, rounding up" do
    { 18 => 16, 24 => 13 }.each do |hits, left|
      SpeakCapture.clear
      scene = mine_scene(MiningGameCursor.new(0, 1), :hits => hits)
      Minigames.mining_wall(scene)
      assert_equal [t(:mg_wall_left, :n => left)], SpeakCapture.lines, "#{hits} hits"
    end
  end

  test "a caved-in mining wall says nothing" do
    [48, 49, 54].each do |hits|
      scene = mine_scene(MiningGameCursor.new(0), :hits => hits)
      Minigames.mining_wall(scene)
    end
    assert_equal [t(:mg_wall_left, :n => 1)], SpeakCapture.lines, "one hit left, then none"
  end

  test "a mining scene with no crack bar says nothing" do
    scene = mine_scene(MiningGameCursor.new(0))
    scene.instance_variable_get(:@sprites).delete("crack")
    Minigames.mining_wall(scene)
    assert_nothing_spoken
  end

  test "a reader handed a number it cannot read says nothing and raises nothing" do
    odd = Object.new
    board = vf_scene
    board.instance_variable_set(:@index, [odd, 0])
    lost = MiningGameCursor.new(odd)
    readers = { "the Voltorb Flip cursor" => lambda { Minigames.voltorb_flip(board) },
                "the mining cursor" => lambda { with_mine(nil) { Minigames.mining_cursor(lost) } },
                "the cursor's square after a blow" => lambda { Minigames.mining_after_hit(mine_scene(lost)) },
                "the cracks in the wall" => lambda { Minigames.mining_wall(mine_scene(lost, :hits => odd)) } }
    readers.each { |what, read| assert_nil read.call, what }
    assert_nothing_spoken
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A Voltorb Flip board as the game keeps it, [x, y, value, turned] per card in reading order.
  def vf_squares(values, turned = [])
    values.each_with_index.map { |v, i| [(i % 5) * 64 + 128, (i / 5) * 64, v, turned.include?(i)] }
  end

  # The game's mark on the card in column col, row row.
  def vf_mark(col, row)
    ["tiles", col * 64 + 128, row * 64, 256, 0, 64, 64]
  end

  # A Voltorb Flip scene on VF_VALUES, nothing turned or marked, its cursor on the top left in the normal mode.
  def vf_scene(opts = {})
    World.stub_scene(:@squares => vf_squares(VF_VALUES), :@index => [0, 0], :@marks => [],
                     :@cursor => [["cursor", 128, 0, 0, 0, 64, 64]], :@points => 0, :@level => opts.fetch(:level, 1))
  end

  # A row's or column's counts as the board edge shows them.
  def vf_line(label, sum, voltorbs)
    t(:mg_line, :label => t(label), :sum => sum, :voltorbs => voltorbs)
  end

  # The keys a gen-6 Voltorb Flip board paints, as said: Ctrl opens the memo, X quits.
  def vf_keys
    "#{t(:mg_vf_memo_key, :key => t(:key_control))}. #{t(:piano_exit, :key => 'X')}"
  end

  # Runs the block with the player holding n coins in the Coin Case, on the holder the newest era keeps them on.
  def with_coins(n)
    had = $player
    $player = Struct.new(:coins).new(n)
    yield
  ensure
    $player = had
  end

  # A wall square's row and column as said.
  def rowcol(row, col)
    t(:mg_rowcol, :row => row, :col => col)
  end

  # A Triple Triad scene over duel, with the hand slots of each side.
  def triad_scene(duel, hand = [], rival = [])
    World.stub_scene(:@battle => duel, :@cardIndexes => hand, :@opponentCardIndexes => rival)
  end

  # A Triple Triad scene whose help window shows text.
  def triad_help_scene(text)
    World.stub_scene(:@sprites => { "helpwindow" => HelpWindow.new(text) })
  end

  def help_of(scene)
    scene.instance_variable_get(:@sprites)["helpwindow"]
  end

  # The block's value with the deck selector open on scene over storage ([species, count] per row), closed after.
  def in_deck(scene, storage = [])
    Triad.start_deck(scene, storage)
    yield
  ensure
    Triad.stop
  end

  # Runs the block with the mod's clock a second ahead, past the dialogue's half-second dedup.
  def a_second_later
    real = PokeAccess.method(:clock)
    PokeAccess.define_singleton_method(:clock) { real.call + 1.0 }
    yield
  ensure
    PokeAccess.define_singleton_method(:clock, real)
  end

  # A mining wall with its cursor; opts :items and :iron the squares hiding them, :hits the cracks so far.
  def mine_scene(cursor, opts = {})
    MiningGameScene.new(opts.fetch(:items, []), opts.fetch(:iron, []), cursor, opts.fetch(:hits, 0))
  end

  def crack_of(scene)
    scene.instance_variable_get(:@sprites)["crack"]
  end

  # The block's value with scene as the mine being played (nil for none), none after.
  def with_mine(scene)
    Minigames.mine_scene = scene
    yield
  ensure
    Minigames.mine_scene = nil
  end

  # Runs the block with the game's MiningGameScene spelling the wall's width as name, then puts back the class there
  # was before.
  def with_board_width(name, width)
    had = Object.const_defined?(:MiningGameScene, false) ? Object.const_get(:MiningGameScene) : nil
    Object.send(:remove_const, :MiningGameScene) if had
    game_scene = Class.new
    game_scene.const_set(name, width)
    Object.const_set(:MiningGameScene, game_scene)
    yield
  ensure
    Object.send(:remove_const, :MiningGameScene) if Object.const_defined?(:MiningGameScene, false)
    Object.const_set(:MiningGameScene, had) if had
  end
end
