# Yuko115's Blackjack (plugins/bes_blackjack.rb, pbBlackJack): the offers and results are the game's messages, so the
# plugin adds the player's total, the one number the table paints, said whenever it changes and queued.

# What the table paints, in the order a game paints it: one list of text positions per offer to draw a card.
module BesBlackjackTable
  class << self
    attr_accessor :paints
  end
  self.paints = []
end

# The game's function, cut down to its paints: the loop's messages are the standard ones and not the plugin's.
def pbBlackJack
  BesBlackjackTable.paints.each { |rows| pbDrawTextPositions(nil, rows) }
  :table_closed
end

# The plugin's wrap of the function, which the harness's own load of the file made before the function existed; its
# wrap of the paint, made then, is the one that runs.
BES_BLACKJACK_WRAP = Harness.source(File.join(Harness::ROOT, "plugins", "bes_blackjack.rb"))
                            .match(/^PokeAccess::Hooks\.wrap_kernel\("pbBlackJack".*?^end\n/m)[0]
eval(BES_BLACKJACK_WRAP, TOPLEVEL_BINDING, "plugins/bes_blackjack.rb")

class BesBlackjackTest < PokeAccessTest
  LABELS = { "bjack_total" => "Suma total: %{n}" }.freeze

  def setup
    super
    table = PokeAccess::I18n.table(:es)
    @added = LABELS.keys.reject { |k| table.key?(k) }
    @added.each { |k| table[k] = LABELS[k] }
  end

  def teardown
    @added.each { |k| PokeAccess::I18n.table(:es).delete(k) }
    BesBlackjackTable.paints = []
    super
  end

  test "says the total as the table paints it, each new value queued" do
    play([total(0), total(7), total(15)])
    assert_equal [["Suma total: 0", false], ["Suma total: 7", false], ["Suma total: 15", false]], SpeakCapture.log
  end

  test "says a total once however often it is painted" do
    play([total(0), total(0), total(7), total(7), total(7), total(0)])
    assert_equal ["Suma total: 0", "Suma total: 7", "Suma total: 0"], SpeakCapture.lines
  end

  test "a new game says its first total again" do
    2.times { play([total(5)]) }
    assert_equal ["Suma total: 5", "Suma total: 5"], SpeakCapture.lines
  end

  test "takes a total painted with spaces around it" do
    play([[[" 12 ", 17, 230, 0]]])
    assert_equal ["Suma total: 12"], SpeakCapture.lines
  end

  test "says nothing for a paint that is not the one number alone" do
    play([[["7", 17, 230, 0], ["8", 17, 260, 0]], [["Puntos", 17, 230, 0]], [["-3", 17, 230, 0]], [["", 17, 230, 0]], [],
          [["7"]], [nil]])
    assert_equal ["Suma total: 7"], SpeakCapture.lines
  end

  test "says nothing for text painted outside the game" do
    pbDrawTextPositions(nil, total(7))
    assert_nothing_spoken
  end

  test "the total said last is forgotten when the game ends" do
    play([total(7)])
    SpeakCapture.clear
    pbDrawTextPositions(nil, total(7))
    assert_nothing_spoken
  end

  test "hands back what the game returns" do
    BesBlackjackTable.paints = [total(3)]
    assert_equal :table_closed, pbBlackJack
  end

  private

  def total(n)
    [[n.to_s, 17, 230, 0]]
  end

  def play(paints)
    BesBlackjackTable.paints = paints
    pbBlackJack
  end
end
