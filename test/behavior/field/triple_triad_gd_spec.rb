# Triple Triad on the modern path. Same reader, same scene ivars, but species are symbols instead of
# integers here, and the slot-versus-species confusion reads differently: in gen-6 it named a wrong Pokemon,
# in the GameData era a slot number is not a species at all, so the line degraded to a bare "1" or "2".
# Both eras ship this minigame, so the fix has to hold in both -- the gen-6 half lives in triple_triad_spec.

# See the gen-6 twin: slots = @cardIndexes (sprite slots in hand order), cards = @playerCards BY SLOT.
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
