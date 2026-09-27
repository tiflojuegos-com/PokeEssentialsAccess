# Triple Triad hand and board reading (core/field/minigame_text). @cardIndexes holds sprite slots in hand order, not
# species: the card is @playerCards at that slot. The first poll after start_hand reads the focused card with no key.

# A TriadScene stand-in: slots = @cardIndexes (sprite slots in hand order), cards = @playerCards by slot.
def triad_hand(slots, cards)
  s = Object.new
  s.instance_variable_set(:@cardIndexes, slots)
  s.instance_variable_set(:@playerCards, cards)
  s
end

# A stand-in for the TriadBattle grid the board cursor reads.
class FakeTriadBattle
  def initialize(width, height, occupied = {}, owners = {})
    @width = width; @height = height; @occupied = occupied; @owners = owners
  end
  attr_reader :width, :height
  def isOccupied?(x, y); @occupied[[x, y]] ? true : false; end
  def getOwner(x, y); @owners[[x, y]]; end
end

def triad_board(battle)
  s = Object.new
  s.instance_variable_set(:@battle, battle)
  s
end

Suite.define("triple triad: the hand names the species at the focused slot, not the slot number") do
  PokeAccess::TripleTriad.start_hand(triad_hand([2, 0], [11, 22, 33]))
  begin
    PokeAccess::TripleTriad.poll
    spoke "hand position 0 sits on slot 2, so species 33 is named", /Especie33/
    not_spoke "the slot number is never mistaken for a species", /Especie2\b/
  ensure
    PokeAccess::TripleTriad.stop
  end
end

Suite.define("triple triad: a hand whose slots match its order still reads correctly") do
  PokeAccess::TripleTriad.start_hand(triad_hand([0, 1, 2], [77, 88, 99]))
  begin
    PokeAccess::TripleTriad.poll
    spoke "the untouched hand names its first card", /Especie77/
  ensure
    PokeAccess::TripleTriad.stop
  end
end

Suite.define("triple triad: a hand missing its @playerCards stays silent instead of inventing a card") do
  s = Object.new
  s.instance_variable_set(:@cardIndexes, [0, 1])
  PokeAccess::TripleTriad.start_hand(s)
  begin
    PokeAccess::TripleTriad.poll
    silent "no species can be resolved, so nothing is announced"
  ensure
    PokeAccess::TripleTriad.stop
  end
end

Suite.define("triple triad: the board cursor reads the cell and who holds it") do
  battle = FakeTriadBattle.new(3, 3, { [0, 0] => true }, { [0, 0] => 1 })
  PokeAccess::TripleTriad.start_board(triad_board(battle))
  begin
    PokeAccess::TripleTriad.poll
    spoke "the occupied top-left cell is named as the player's",
          /#{PokeAccess::I18n.t(:triad_yours)}/
  ensure
    PokeAccess::TripleTriad.stop
  end
end

Suite.define("triple triad: an empty cell is announced as free") do
  PokeAccess::TripleTriad.start_board(triad_board(FakeTriadBattle.new(3, 3)))
  begin
    PokeAccess::TripleTriad.poll
    spoke "an unplayed cell is free", /#{PokeAccess::I18n.t(:triad_free)}/
  ensure
    PokeAccess::TripleTriad.stop
  end
end

Suite.define("triple triad: nesting the hand inside the board restores the outer mode on stop") do
  PokeAccess::TripleTriad.start_board(triad_board(FakeTriadBattle.new(3, 3)))
  begin
    PokeAccess::TripleTriad.start_hand(triad_hand([1], [11, 22]))
    PokeAccess::TripleTriad.stop
    SpeakCapture.clear
    PokeAccess::TripleTriad.poll
    spoke "the board is read again once the hand picker closes",
          /#{PokeAccess::I18n.t(:triad_free)}/
  ensure
    PokeAccess::TripleTriad.stop
  end
end

# The card shop reads the card createBitmap draws beside the focused row, its four sides, once per species; outside
# the shop the same call stays silent.
Suite.define("triple triad: the shop reads the card beside the row, and nothing outside the shop") do
  SpeakCapture.clear
  TriadCard.new(4).createBitmap(1)
  silent "a card drawn outside the shop says nothing"

  $triad_shop_script = [4, 4, 7]
  SpeakCapture.clear
  pbBuyTriads
  lines = SpeakCapture.lines
  eq "one line per card the focus lands on, and none for standing still", lines.length, 2
  match "the first card is named with its four sides", lines[0],
        /#{Regexp.escape(PokeAccess::I18n.t(:triad_sides, :n => 5, :e => 8, :s => 10, :w => 2))}/
  match "and the next one with its own", lines[1],
        /#{Regexp.escape(PokeAccess::I18n.t(:triad_sides, :n => 8, :e => 1, :s => 3, :w => 5))}/

  SpeakCapture.clear
  TriadCard.new(4).createBitmap(1)
  silent "and once the shop is closed the reader is quiet again"

  $triad_shop_script = [4]
  SpeakCapture.clear
  pbSellTriads
  spoke "selling reads the same way", /#{Regexp.escape(PokeAccess::I18n.t(:triad_sides, :n => 5, :e => 8, :s => 10, :w => 2))}/
  $triad_shop_script = nil
end

# A taken square names its owner and card; the opponent's move is said queued, the score it changed queued behind it,
# and a change from the player's own move interrupts.
Suite.define("triple triad: a taken square names its card, and the opponent's move is said") do
  tt = PokeAccess::TripleTriad
  t = PokeAccess::I18n
  square = Struct.new(:owner, :card).new(2, TriadCard.new(4))
  bt = Object.new
  bt.instance_variable_set(:@sq, square)
  def bt.isOccupied?(_x, _y); true; end
  def bt.getOwner(_x, _y); 2; end
  def bt.getPanel(_x, _y); @sq; end
  line = tt.cell_text(bt, 1, 0)
  eq "the square, its owner and the card on it",
     line, "#{t.t(:triad_cell, :row => 1, :col => 2)}, #{t.t(:triad_theirs)}, #{tt.card_text(4)}"

  SpeakCapture.clear
  tt.opponent_played(TriadCard.new(4), [2, 1])
  eq "the opponent's card and where it landed, queued",
     SpeakCapture.log, [[t.t(:triad_foe_plays, :card => tt.card_text(4), :row => 2, :col => 3), false]]

  owners = [2, 0, 0, 0]
  duel = Object.new
  duel.instance_variable_set(:@o, owners)
  def duel.width; 2; end
  def duel.height; 2; end
  def duel.board; @o.map { |w| Struct.new(:owner).new(w) }; end
  def duel.countUnplayedCards; false; end
  scene = Object.new
  scene.instance_variable_set(:@battle, duel)
  SpeakCapture.clear
  tt.opponent_played(TriadCard.new(4), [0, 0])
  tt.score(scene)
  eq "the score the opponent's move changed follows it, queued", SpeakCapture.log,
     [[t.t(:triad_foe_plays, :card => tt.card_text(4), :row => 1, :col => 1), false],
      [t.t(:triad_score, :you => 0, :foe => 1), false]]
  SpeakCapture.clear
  owners[1] = 1
  tt.score(scene)
  eq "and the next change, from the player's own move, interrupts", SpeakCapture.log,
     [[t.t(:triad_score, :you => 1, :foe => 1), true]]
end

# The rival's move and the score it changed are queued and the game goes straight from them into the player's
# next turn, so the first card that loop focuses queues behind them too; only a key the player presses interrupts.
Suite.define("triple triad: the next turn's first card waits for the rival's move and the score") do
  tt = PokeAccess::TripleTriad
  scene = triad_hand([0, 1], [11, 22])
  SpeakCapture.clear
  tt.opponent_played(TriadCard.new(4), [0, 0])
  tt.score(scene)
  tt.start_hand(scene)
  begin
    tt.poll
    eq "the rival's move, then the hand's first card, both queued", SpeakCapture.log.map { |l| l[1] }, [false, false]
    SpeakCapture.clear
    Input.singleton_class.send(:alias_method, :triad_repeat, :repeat?)
    Input.define_singleton_method(:repeat?) { |k| k == Input::DOWN }
    tt.poll
    eq "a card reached with a key interrupts", SpeakCapture.log, [[tt.card_text(22), true]]
  ensure
    if Input.singleton_class.method_defined?(:triad_repeat)
      Input.singleton_class.send(:alias_method, :repeat?, :triad_repeat)
      Input.singleton_class.send(:remove_method, :triad_repeat)
    end
    tt.stop
  end

  tt.start_hand(scene)
  tt.start_opponent(scene)
  tt.stop_opponent
  SpeakCapture.clear
  tt.poll
  eq "closing the rival's hand puts the cursor back on the first card, which answers that key",
     SpeakCapture.log, [[tt.card_text(11), true]]
  tt.stop
end

# A card says its type after the species; under the "elements" rule a free square says its element (-1 is none).
Suite.define("triple triad: a card says its type, and a free square its element under the elements rule") do
  tt = PokeAccess::TripleTriad
  t = PokeAccess::I18n
  truthy "the card line names the type right after the species",
         tt.card_text(4).to_s.start_with?("#{PokeAccess::Data.species_name(4)}, #{t.t(:mv_type, :t => PBTypes.getName(1))}, ")
  squares = [Struct.new(:type).new(2), Struct.new(:type).new(-1)]
  bt = Object.new
  bt.instance_variable_set(:@sq, squares)
  def bt.width; 2; end
  def bt.isOccupied?(_x, _y); false; end
  def bt.board; @sq; end
  eq "a free square dealt an element says it", tt.cell_text(bt, 0, 0),
     "#{t.t(:triad_cell, :row => 1, :col => 1)}, #{t.t(:triad_free)}, #{t.t(:triad_element, :t => PBTypes.getName(2))}"
  eq "one with none (gen-6 marks it -1) is only free", tt.cell_text(bt, 1, 0),
     "#{t.t(:triad_cell, :row => 1, :col => 2)}, #{t.t(:triad_free)}"
end

# The squares a move captures are named before the score; the square just played is not.
Suite.define("triple triad: the squares a move captures are said before the score") do
  tt = PokeAccess::TripleTriad
  t = PokeAccess::I18n
  owners = [2, 0, 0, 0]
  duel = Object.new
  duel.instance_variable_set(:@o, owners)
  def duel.width; 2; end
  def duel.height; 2; end
  def duel.board; @o.map { |w| Struct.new(:owner).new(w) }; end
  def duel.countUnplayedCards; false; end
  scene = Object.new
  scene.instance_variable_set(:@battle, duel)
  SpeakCapture.clear
  tt.score(scene)
  eq "the first count of a duel has nothing to compare with", SpeakCapture.lines, [t.t(:triad_score, :you => 0, :foe => 1)]
  owners[0] = 1
  owners[1] = 1
  SpeakCapture.clear
  tt.score(scene)
  eq "the square that changed colour is named, the one just played is not", SpeakCapture.lines,
     ["#{t.t(:triad_captures, :list => t.t(:triad_cell, :row => 1, :col => 1))}. #{t.t(:triad_score, :you => 2, :foe => 0)}"]
end
