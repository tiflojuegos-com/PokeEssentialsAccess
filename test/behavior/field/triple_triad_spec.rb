# Triple Triad hand and board reading (core/field/minigame_text). The minigame ships in all thirteen games
# with the same scene ivars, so a mistake here is thirteen games wrong at once -- and it had no coverage.
#
# What this pins: @cardIndexes holds SPRITE SLOTS, not species. The game pushes one entry per card in
# creation order and deletes the entry when a card is played, so a hand position stops matching its slot as
# soon as one card leaves the hand. The species lives in @playerCards at that slot -- the game itself does
# TriadCard.new(@playerCards[spriteIndex]) -- and feeding the slot straight to the card builder names
# whatever species shares that number, confidently and with four made-up side values.
#
# Input.repeat? is false under the stubs, but start_hand leaves @last nil, so the first poll announces the
# focused position with no keypress: that is the real path, driven end to end.

# A stand-in for the game's TriadScene. slots = @cardIndexes (sprite slots in hand order), cards =
# @playerCards indexed BY SLOT, so the two deliberately disagree.
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
