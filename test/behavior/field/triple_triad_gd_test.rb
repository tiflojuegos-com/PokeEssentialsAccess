# Triple Triad's hand where species are symbols (GameData era): the hand names the species at the focused slot,
# never the slot number, and with no card class to build the card from it says the species alone.
class TripleTriadGdTest < PokeAccessTest
  # The module's state as it loads, which each test starts from; the state before the test is put back after it.
  FRESH = { :@mode => nil, :@scene => nil, :@choice => 0, :@bx => 0, :@by => 0, :@last => nil, :@storage => nil,
            :@stack => nil, :@after_foe => nil, :@shop => nil }.freeze

  def setup
    super
    @saved_triad = FRESH.keys.map { |iv| [iv, tt.instance_variable_get(iv)] }
    FRESH.each { |iv, v| tt.instance_variable_set(iv, v) }
  end

  def teardown
    @saved_triad.each { |iv, v| tt.instance_variable_set(iv, v) }
    super
  end

  test "the hand names the species symbol at the focused slot, queued as the picker opens" do
    { [[2, 0], [:BULBASAUR, :CHARMANDER, :SQUIRTLE]] => "SpeciesSQUIRTLE",
      [[1], [:ABRA, :KADABRA, :ALAKAZAM]] => "SpeciesKADABRA" }.each do |(slots, cards), name|
      SpeakCapture.clear
      hand = Object.new
      hand.instance_variable_set(:@cardIndexes, slots)
      hand.instance_variable_set(:@playerCards, cards)
      tt.start_hand(hand)
      tt.poll
      tt.stop
      assert_equal [[name, false]], SpeakCapture.log, "slots #{slots.inspect}"
    end
  end

  private

  def tt; PokeAccess::TripleTriad; end
end
