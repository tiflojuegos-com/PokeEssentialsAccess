# Triple Triad in the gamedata pass, where species are symbols: the hand names the species at the focused slot, never
# the slot number.

# A TriadScene stand-in: slots = @cardIndexes (sprite slots in hand order), cards = @playerCards by slot.
def triad_hand(slots, cards)
  s = Object.new
  s.instance_variable_set(:@cardIndexes, slots)
  s.instance_variable_set(:@playerCards, cards)
  s
end

Suite.define("triple triad (gamedata): the hand names the species symbol at the focused slot") do
  PokeAccess::TripleTriad.start_hand(triad_hand([2, 0], [:BULBASAUR, :CHARMANDER, :SQUIRTLE]))
  begin
    PokeAccess::TripleTriad.poll
    spoke "hand position 0 sits on slot 2, so that species is named", /SpeciesSQUIRTLE/
    not_spoke "the bare slot number is never spoken as the card", /\ASpecies2\z/
  ensure
    PokeAccess::TripleTriad.stop
  end
end

Suite.define("triple triad (gamedata): a hand shortened by played cards keeps naming the right species") do
  PokeAccess::TripleTriad.start_hand(triad_hand([1], [:ABRA, :KADABRA, :ALAKAZAM]))
  begin
    PokeAccess::TripleTriad.poll
    spoke "the one card left resolves through its own slot", /SpeciesKADABRA/
  ensure
    PokeAccess::TripleTriad.stop
  end
end
