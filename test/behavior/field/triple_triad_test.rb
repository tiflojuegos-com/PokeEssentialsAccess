# Triple Triad (core/field/minigame_text): the hand, the rival's hand and the board read their focus as it moves, the
# rival's move and the score it changed queue, the squares a move flips come first, and the shop reads its card.

# The duel screen as the game runs it, each loop cut down to the frames the test runs inside it (the block); the
# hooks of minigame_text.rb bind to it below, as they bind to the game's own TriadScene.
class TriadScene
  def initialize(ivars = {})
    ivars.each { |k, v| instance_variable_set(k, v) }
  end

  def pbChooseTriadCard(_cards); yield if block_given?; end
  def pbPlayerChooseCard(_num_cards); yield if block_given?; 0; end
  def pbPlayerPlaceCard(_card, _card_index); yield if block_given?; [0, 0]; end
  def pbViewOpponentCards(_num_cards); yield if block_given?; end
  def pbOpponentPlaceCard(_card, _position, _card_index); end
  def pbUpdateScore; end
  def pbDisplay(_text); end
  def pbDisplayPaused(_text); end
end

# The duel screen's hooks, bound to the stand-in: the help-window lines and the loops, score and rival's placement.
triad_path = File.join(Harness::ROOT, "core", "field", "minigame_text.rb")
triad_src = Harness.source(triad_path)
[/^\["TriadScene", "TriadScreen"\]\.each do \|cn\|\n  \["pbDisplay".*?^end\n/m,
 /^\["TriadScene", "TriadScreen"\]\.each do \|cn\|\n  PokeAccess::Hooks\.around_hook.*?^end\n/m].each do |re|
  found = triad_src.match(re)
  eval(found[0], TOPLEVEL_BINDING, triad_path, triad_src[0, found.begin(0)].count("\n") + 1)
end

class TripleTriadTest < PokeAccessTest
  # The module's state as it loads, which each test starts from; the state before the test is put back after it.
  FRESH = { :@mode => nil, :@scene => nil, :@choice => 0, :@bx => 0, :@by => 0, :@last => nil, :@storage => nil,
            :@stack => nil, :@after_foe => nil, :@shop => nil }.freeze

  # The board as the readers ask it: its size, the squares as a flat list (owner, the card on it, the element the
  # "elements" rule dealt it), who holds a square and the card on it.
  class Board
    Square = Struct.new(:owner, :card, :type)
    attr_reader :width, :height, :board

    def initialize(width = 3, height = 3)
      @width = width
      @height = height
      @board = Array.new(width * height) { Square.new(0, nil, -1) }
    end

    def square(x, y); @board[y * @width + x]; end
    def isOccupied?(x, y); square(x, y).owner > 0; end
    def getOwner(x, y); square(x, y).owner; end
    def getPanel(x, y); square(x, y); end
    def countUnplayedCards; false; end
  end

  # A board of an engine that keeps no size on it: the reader takes the 3 by 3 grid.
  class SizelessBoard < Board
    undef_method :width, :height
  end

  def setup
    super
    @saved_triad = FRESH.keys.map { |iv| [iv, tt.instance_variable_get(iv)] }
    FRESH.each { |iv, v| tt.instance_variable_set(iv, v) }
  end

  def teardown
    @saved_triad.each { |iv, v| tt.instance_variable_set(iv, v) }
    super
  end

  test "a card is read as its species, its type and its four sides, top first" do
    { 4 => ["Especie4", 1, 5, 8, 10, 2], 33 => ["Especie33", 0, 4, 7, 9, 1] }.each do |sp, (species, type, n, e, s, w)|
      name = "#{species}, #{t(:mv_type, :t => PBTypes.getName(type))}"
      assert_equal t(:triad_card, :name => name, :n => n, :e => e, :s => s, :w => w), tt.card_text(sp), "species #{sp}"
    end
  end

  test "a taken square names whose it is and the card on it" do
    b = Board.new
    b.square(1, 0).owner = 1
    b.square(1, 0).card = TriadCard.new(4)
    b.square(0, 1).owner = 2
    b.square(0, 1).card = TriadCard.new(33)
    b.square(2, 2).owner = 2
    { [1, 0] => cell(1, 2, t(:triad_yours), tt.card_text(4)), [0, 1] => cell(2, 1, t(:triad_theirs), tt.card_text(33)),
      [2, 2] => cell(3, 3, t(:triad_theirs)) }.each do |(x, y), want|
      assert_equal want, tt.cell_text(b, x, y), "square #{x}, #{y}"
    end
  end

  test "a free square says the element the elements rule dealt it, and nothing more without one" do
    b = Board.new(4, 1)
    [2, 0, -1, nil].each_with_index { |type, x| b.square(x, 0).type = type }
    free = t(:triad_free)
    { 0 => cell(1, 1, free, t(:triad_element, :t => PBTypes.getName(2))),
      1 => cell(1, 2, free, t(:triad_element, :t => PBTypes.getName(0))),
      2 => cell(1, 3, free), 3 => cell(1, 4, free) }.each do |x, want|
      assert_equal want, tt.cell_text(b, x, 0), "square #{x}"
    end
  end

  test "the hand reads the card at the focused slot, queued as the picker opens" do
    [[[2, 0], [11, 22, 33], 33], [[0, 1, 2], [77, 88, 99], 77], [[1], [11, 22], 22]].each do |slots, cards, sp|
      SpeakCapture.clear
      tt.start_hand(scene(:@cardIndexes => slots, :@playerCards => cards))
      tt.poll
      tt.stop
      assert_equal [[tt.card_text(sp), false]], SpeakCapture.log, "slots #{slots.inspect}"
    end
  end

  test "a hand with no cards to name says nothing" do
    { "no card list" => { :@cardIndexes => [0, 1] }, "no slots" => { :@cardIndexes => [], :@playerCards => [11] },
      "slots that are no list" => { :@cardIndexes => 2, :@playerCards => [11, 22] } }.each do |what, ivars|
      tt.start_hand(scene(ivars))
      tt.poll
      tt.stop
      assert_nothing_spoken what
    end
  end

  test "DOWN and UP move over the hand, interrupting, and wrap at either end" do
    tt.start_hand(scene(:@cardIndexes => [0, 1, 2], :@playerCards => [11, 22, 33]))
    tt.poll
    [Input::DOWN, Input::DOWN, Input::DOWN, Input::UP].each { |key| pressing(key) { tt.poll } }
    assert_equal [[tt.card_text(11), false], [tt.card_text(22), true], [tt.card_text(33), true],
                  [tt.card_text(11), true], [tt.card_text(33), true]], SpeakCapture.log
  end

  test "a frame without a key says nothing more about the card in focus" do
    tt.start_hand(scene(:@cardIndexes => [0, 1], :@playerCards => [11, 22]))
    tt.poll
    SpeakCapture.clear
    tt.poll
    assert_nothing_spoken
  end

  test "the rival's hand reads their card at the cursor, and a place past their last card as no card" do
    tt.start_opponent(scene(:@cardIndexes => [0, 1], :@opponentCardIndexes => [1], :@opponentCards => [44, 55]))
    tt.poll
    tt.poll
    pressing(Input::DOWN) { tt.poll }
    assert_equal [[tt.card_text(55), false], [t(:triad_no_card), true]], SpeakCapture.log
  end

  test "the rival's hand wraps by the player's own card count, one card included" do
    tt.start_opponent(scene(:@cardIndexes => [3], :@opponentCardIndexes => [0, 1], :@opponentCards => [44, 55]))
    tt.poll
    pressing(Input::DOWN) { tt.poll }
    assert_equal [[tt.card_text(44), false]], SpeakCapture.log
  end

  test "closing the rival's hand puts the cursor back on the first card, read as a move" do
    hand = scene(:@cardIndexes => [0, 1], :@playerCards => [11, 22])
    tt.start_hand(hand)
    tt.start_opponent(hand)
    tt.stop_opponent
    tt.poll
    assert_equal [[tt.card_text(11), true]], SpeakCapture.log
  end

  test "closing a loop opened inside another hands the reading back to the outer one" do
    tt.start_board(scene(:@battle => Board.new))
    tt.start_hand(scene(:@cardIndexes => [1], :@playerCards => [11, 22]))
    tt.stop
    tt.poll
    assert_equal [[cell(1, 1, t(:triad_free)), false]], SpeakCapture.log
  end

  test "the board placer opens on the top-left square, queued" do
    tt.start_board(scene(:@battle => Board.new))
    tt.poll
    assert_equal [[cell(1, 1, t(:triad_free)), false]], SpeakCapture.log
  end

  test "the arrows move over the board, interrupting, and wrap at its edges" do
    tt.start_board(scene(:@battle => Board.new(3, 2)))
    tt.poll
    keys = [Input::LEFT, Input::RIGHT, Input::UP, Input::DOWN, Input::RIGHT, Input::DOWN]
    keys.each { |key| pressing(key) { tt.poll } }
    free = t(:triad_free)
    assert_equal [[cell(1, 1, free), false], [cell(1, 3, free), true], [cell(1, 1, free), true],
                  [cell(2, 1, free), true], [cell(1, 1, free), true], [cell(1, 2, free), true],
                  [cell(2, 2, free), true]], SpeakCapture.log
  end

  test "a board that keeps no size wraps as the 3 by 3 grid" do
    tt.start_board(scene(:@battle => SizelessBoard.new))
    tt.poll
    [Input::UP, Input::LEFT].each { |key| pressing(key) { tt.poll } }
    free = t(:triad_free)
    assert_equal [[cell(1, 1, free), false], [cell(3, 1, free), true], [cell(3, 3, free), true]], SpeakCapture.log
  end

  test "a placer with no board to read says nothing" do
    tt.start_board(scene)
    tt.poll
    assert_nothing_spoken
  end

  test "the card picker and the board placer are read while the game runs them, and not once they return" do
    hand = scene(:@cardIndexes => [1, 0], :@playerCards => [11, 22], :@battle => Board.new)
    hand.pbPlayerChooseCard(2) { tt.poll }
    hand.pbPlayerPlaceCard(TriadCard.new(22), 0) { tt.poll }
    pressing(Input::DOWN) { tt.poll }
    assert_equal [[tt.card_text(22), false], [cell(1, 1, t(:triad_free)), false]], SpeakCapture.log
  end

  test "the rival's hand, opened from the card picker, gives the cursor back to the picker's first card" do
    duel = scene(:@cardIndexes => [0, 1], :@playerCards => [11, 22], :@opponentCardIndexes => [0],
                 :@opponentCards => [44])
    duel.pbPlayerChooseCard(2) do
      tt.poll
      pressing(Input::DOWN) { tt.poll }
      duel.pbViewOpponentCards(2) { tt.poll }
      tt.poll
    end
    assert_equal [[tt.card_text(11), false], [tt.card_text(22), true], [tt.card_text(44), false],
                  [tt.card_text(11), true]], SpeakCapture.log
  end

  test "the rival's placement is said with the card and the square the game places it on" do
    scene.pbOpponentPlaceCard(TriadCard.new(4), [2, 1], 0)
    assert_equal [[t(:triad_foe_plays, :card => tt.card_text(4), :row => 2, :col => 3), false]], SpeakCapture.log
  end

  test "a rival's placement with no card or no square says nothing" do
    duel = scene
    duel.pbOpponentPlaceCard(Object.new, [0, 0], 0)
    duel.pbOpponentPlaceCard(TriadCard.new(4), nil, 0)
    assert_nothing_spoken
  end

  test "the score is said each time the game redraws it changed" do
    b = Board.new(2, 1)
    duel = scene(:@battle => b)
    b.square(0, 0).owner = 1
    duel.pbUpdateScore
    duel.pbUpdateScore
    b.square(1, 0).owner = 2
    duel.pbUpdateScore
    assert_equal [[t(:triad_score, :you => 1, :foe => 0), true],
                  [t(:triad_score, :you => 1, :foe => 1), true]], SpeakCapture.log
  end

  test "a score redrawn with no board says nothing" do
    scene.pbUpdateScore
    assert_nothing_spoken
  end

  test "the score the rival's placement changed queues behind it, and the next change interrupts" do
    b = Board.new(2, 2)
    duel = scene(:@battle => b)
    b.square(0, 0).owner = 2
    duel.pbOpponentPlaceCard(TriadCard.new(4), [0, 0], 0)
    duel.pbUpdateScore
    b.square(1, 0).owner = 1
    duel.pbUpdateScore
    assert_equal [[t(:triad_foe_plays, :card => tt.card_text(4), :row => 1, :col => 1), false],
                  [t(:triad_score, :you => 0, :foe => 1), false],
                  [t(:triad_score, :you => 1, :foe => 1), true]], SpeakCapture.log
  end

  test "the squares a move flips are named before the score, the square just played is not" do
    b = Board.new
    duel = scene(:@battle => b)
    b.square(0, 0).owner = 2
    b.square(2, 1).owner = 2
    duel.pbUpdateScore
    SpeakCapture.clear
    [[0, 0], [1, 1], [2, 1]].each { |x, y| b.square(x, y).owner = 1 }
    duel.pbUpdateScore
    flipped = [cell(1, 1), cell(2, 3)].join("; ")
    assert_equal [["#{t(:triad_captures, :list => flipped)}. #{t(:triad_score, :you => 3, :foe => 0)}", true]],
                 SpeakCapture.log
  end

  test "a deck row adds its card's type and sides while the game runs the deck chooser, and not once it returns" do
    rows = deck_window(["Bulbasaur x3"])
    inside = nil
    scene.pbChooseTriadCard([[1, 3]]) { inside = tt.deck_row(rows, 0) }
    sides = t(:triad_sides, :n => 2, :e => 5, :s => 7, :w => 9)
    assert_equal ["Bulbasaur x3, #{t(:mv_type, :t => PBTypes.getName(1))}, #{sides}", "Bulbasaur x3"],
                 [inside, tt.deck_row(rows, 0)], "the row inside the chooser, then once it returns"
  end

  test "in the deck chooser, a row whose card the game cannot build reads as the list writes it" do
    rows = deck_window(["Bulbasaur x3", "Unown x1"])
    inside = nil
    scene.pbChooseTriadCard([[1, 3], [:UNOWN_Q, 1]]) { inside = tt.deck_row(rows, 1) }
    assert_equal "Unown x1", inside
  end

  test "lines the duel shows through pbDisplay and pbDisplayPaused are read as dialogue" do
    duel = scene
    duel.pbDisplay("El rival elige una carta.")
    duel.pbDisplayPaused("Has ganado el duelo de cartas.")
    assert_equal [["El rival elige una carta.", false], ["Has ganado el duelo de cartas.", false]], SpeakCapture.log
  end

  test "each loop the game opens reads its prompt, even one worded as the last loop's" do
    prompt = Struct.new(:text).new("Elige una carta y luego una casilla libre.")
    duel = scene(:@sprites => { "helpwindow" => prompt })
    loops = { :pbChooseTriadCard => [[[1, 3]]], :pbPlayerChooseCard => [1],
              :pbPlayerPlaceCard => [TriadCard.new(1), 0] }
    loops.each do |opener, args|
      2.times do
        later
        duel.send(opener, *args) { tt.poll }
      end
    end
    assert_equal [[prompt.text, false]] * 6, SpeakCapture.log
  end

  test "both halves of the shop read the card drawn beside the focused row, queued" do
    { :pbBuyTriads => [4, 7], :pbSellTriads => [7, 4] }.each do |shop, rows|
      SpeakCapture.clear
      with_shop_rows(rows) { send(shop) }
      assert_equal rows.map { |sp| [tt.card_text(sp), false] }, SpeakCapture.log, shop.to_s
    end
  end

  test "a card the shop draws twice in a row is said once" do
    tt.shopping(true)
    2.times { TriadCard.new(4).createBitmap(1) }
    assert_equal [[tt.card_text(4), false]], SpeakCapture.log
  end

  test "coming back to the shop reads its first card again" do
    2.times { with_shop_rows([4]) { pbBuyTriads } }
    assert_equal [[tt.card_text(4), false]] * 2, SpeakCapture.log
  end

  test "a card drawn outside the shop says nothing, before it opens or after it closes" do
    TriadCard.new(4).createBitmap(1)
    with_shop_rows([7]) { pbBuyTriads }
    TriadCard.new(4).createBitmap(1)
    assert_equal [[tt.card_text(7), false]], SpeakCapture.log
  end

  private

  def tt; PokeAccess::TripleTriad; end

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # A duel screen carrying the given ivars.
  def scene(ivars = {})
    TriadScene.new(ivars)
  end

  # A square's line: its place, then each of rest.
  def cell(row, col, *rest)
    [t(:triad_cell, :row => row, :col => col), *rest].join(", ")
  end

  # Runs the block with Input.repeat? answering key alone, as a frame where the player presses it.
  def pressing(key)
    Input.singleton_class.send(:alias_method, :triad_test_repeat, :repeat?)
    Input.define_singleton_method(:repeat?) { |k| k == key }
    yield
  ensure
    Input.singleton_class.send(:alias_method, :repeat?, :triad_test_repeat)
    Input.singleton_class.send(:remove_method, :triad_test_repeat)
  end

  # Lets the dialogue dedup forget its last line, as half a second of play would.
  def later
    PokeAccess.instance_variable_set(:@last_say_t, nil)
  end

  # Runs the block with the shop stub walking its focus over rows, one species per row.
  def with_shop_rows(rows)
    was = $triad_shop_script
    $triad_shop_script = rows
    yield
  ensure
    $triad_shop_script = was
  end

  # The deck chooser's command window, its rows as the game writes them.
  def deck_window(rows)
    win = Object.new
    win.instance_variable_set(:@commands, rows)
    win
  end
end
