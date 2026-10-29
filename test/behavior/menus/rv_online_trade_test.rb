# The online trade of the Reborn engine (games/rv_common/online_trade_rv.rb): offering a member says the card
# show_information paints, top to bottom with its types beside the name, at the Pokemon choice's levels, cutting in and
# kept whole on the info key and Ctrl+T, in place of the game's own line about it, which the relay of Reborn's reader
# (on for the whole screen) holds back: no double reading. An egg's card paints nothing and its line is left to the
# relay. Desolation paints the same card with no reader of its own to relay, and Rejuvenation has no such screen, where
# the relay is left alone. The stand-in holds Scene_Trade's name only while the reader binds, so the hook binds to it
# and the other tests keep theirs; the reader's override of the relay is kept aside for these tests alone.
Harness.load_common("rv_common")

# The trade screen as far as the card goes (Reborn's Online/Trade.rb:349-385, Desolation's Trade.rb:320-356): the
# player's member under the selector, painted where both games paint it unless it is an egg, then the line Reborn
# hands its reader, as the relay is passed it.
class RvTradeScene
  def initialize(index); @index = index; end

  def show_information
    pkmn = $Trainer.party[@index - 1]
    moves = (0..3).map { |i| pkmn.moves[i] || "--" }
    textpositions = [[pkmn.name, 4, 0, 0, nil, nil], ["Lv: #{pkmn.level}", 4, 27, 0, nil, nil],
                     [pkmn.ability, 4, 257, 0, nil, nil], [moves[0], 4, 149, 0, nil, nil],
                     [moves[1], 4, 175, 0, nil, nil], [moves[2], 4, 201, 0, nil, nil], [moves[3], 4, 227, 0, nil, nil],
                     [pkmn.item || "NO ITEM", 4, 58, 0, nil, nil]]
    textpositions.push([["♂", "♀"][pkmn.gender], 227, 60, false, nil, nil]) if [0, 1].include?(pkmn.gender)
    pbDrawTextPositions(nil, textpositions) unless pkmn.isEgg?
    PokeAccess::OwnVoiceRV.relay("Your Pokémon: Level #{pkmn.level} #{pkmn.name}")
    :shown
  end
end

class RvOnlineTradeTest < PokeAccessTest
  V = PokeAccess::OwnVoiceRV
  RELAY_STATE = [:@live, :@last_frame, :@cut_first, :@always, :@always_frame, :@active]
  TYPES = { :NORMAL => "Normal", :FIRE => "Fire", :FLYING => "Flying" }
  Mon = Struct.new(:name, :level, :type1, :type2, :item, :gender, :moves, :ability, :egg) do
    def isEgg?; egg ? true : false; end
  end
  Player = Struct.new(:name, :party)

  class << self
    # The reader's version of the relay, kept aside by bind_reader.
    attr_reader :relay
  end

  # Binds the reader once, as boot does on the engine, over the stand-in. Its relay is kept aside and the engine's put
  # back, with the list of overrides, so the other tests of the process keep the engine's; on_trade_screen puts the
  # reader's in for a test.
  def self.bind_reader
    meta = PokeAccess::OwnVoiceRV.singleton_class
    engine = meta.instance_method(:relay)
    overrides = PokeAccess::Hooks.overrides.length
    stub = Object.const_defined?(:Scene_Trade) ? Object.send(:remove_const, :Scene_Trade) : nil
    Object.const_set(:Scene_Trade, RvTradeScene)
    PokeAccess::OnlineTradeRV.bind
    @relay = meta.instance_method(:relay)
  ensure
    Object.send(:remove_const, :Scene_Trade)
    Object.const_set(:Scene_Trade, stub) if stub
    meta.send(:define_method, :relay, engine)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
  end
  bind_reader

  test "offering a member says its card as painted, top to bottom, its types beside the name, cutting in" do
    assert_equal [[eevee_card, true]], offering(1)
  end

  test "a member of two types has both said, in their order, and its four moves and held item as painted" do
    card = "Charizard, #{t(:pc_types, :t => 'Fire Flying')}, Lv: 36, Charcoal, ♂, Flamethrower, Air Slash, " \
           "Earthquake, Roost, Blaze"
    assert_equal [[card, true]], offering(2)
  end

  test "the game's own line about the card is held back from the relay, so the card is not read twice" do
    log = offering(1)
    assert_equal 1, log.length
    refute_match(/Your Pok/, log[0][0])
  end

  test "the info key keeps the card" do
    offering(1)
    assert_equal eevee_card, PokeAccess::Info.info_text
  end

  test "brief says the member's name, medium adds its types, full the whole card" do
    lines = vb_levels do
      SpeakCapture.clear
      offering(1).last[0]
    end
    assert_equal ["Eevee", "Eevee, #{t(:pc_types, :t => 'Normal')}", eevee_card], lines
  end

  test "at brief, the info key and Ctrl+T keep the whole card" do
    PokeAccess::Config.verbosity = :brief
    offering(1)
    assert_equal [eevee_card, eevee_card], [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  ensure
    PokeAccess::Config.verbosity = :full
  end

  test "an egg's card paints nothing, and the game's own line about it is left to the relay" do
    log = on_trade_screen do
      RvTradeScene.new(1).show_information
      RvTradeScene.new(3).show_information
    end
    assert_equal [[eevee_card, true], ["Your Pokémon: Level 1 Egg", false]], log
  end

  test "once the card is painted, the relay says again what the game hands its reader" do
    log = on_trade_screen do
      RvTradeScene.new(1).show_information
      V.relay("Pikachu")
    end
    assert_equal [[eevee_card, true], ["Pikachu", false]], log
  end

  test "the card is painted as the game's would, and said" do
    shown = nil
    log = on_trade_screen { shown = RvTradeScene.new(1).show_information }
    assert_equal [:shown, [[eevee_card, true]]], [shown, log]
  end

  test "where no reader of the game's is relayed, as in Desolation, the card is said all the same" do
    log = on_trade_screen(false) { RvTradeScene.new(2).show_information }
    assert_equal 1, log.length
    assert_match(/\ACharizard, .*, Blaze\z/, log[0][0])
  end

  test "where the game has no trade screen, as Rejuvenation, binding leaves the relay as the engine's" do
    meta = V.singleton_class
    engine = meta.instance_method(:relay)
    overrides = PokeAccess::Hooks.overrides.length
    stub = Object.const_defined?(:Scene_Trade) ? Object.send(:remove_const, :Scene_Trade) : nil
    PokeAccess::OnlineTradeRV.bind
    assert_equal [engine, overrides], [meta.instance_method(:relay), PokeAccess::Hooks.overrides.length]
  ensure
    Object.const_set(:Scene_Trade, stub) if stub
    meta.send(:define_method, :relay, engine)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
  end

  private

  # What was said as the player offered the member at the selector's index (1 to 3).
  def offering(index)
    on_trade_screen { RvTradeScene.new(index).show_information }
  end

  # What was said while the block ran on the trade screen as the game shows it: the relay of the game's reader on for
  # the whole screen (off with relayed false, as no profile installed it), with the reader's override in it; the
  # player's party of three and the game's type names in. The relay, the trainer and the engine's relay are put back
  # after.
  def on_trade_screen(relayed = true)
    meta = V.singleton_class
    engine = meta.instance_method(:relay)
    saved = RELAY_STATE.map { |iv| [iv, V.instance_variable_get(iv)] }
    trainer = $Trainer
    meta.send(:define_method, :relay, self.class.relay)
    V.instance_variable_set(:@active, relayed)
    V.instance_variable_set(:@always, [])
    V.instance_variable_set(:@live, [0])
    V.instance_variable_set(:@last_frame, nil)
    V.instance_variable_set(:@cut_first, false)
    $Trainer = Player.new("Ame", party)
    GameFunctions.with(:getTypeName => lambda { |ty| TYPES[ty].to_s }) { yield }
    SpeakCapture.log
  ensure
    $Trainer = trainer
    saved.each { |iv, value| V.instance_variable_set(iv, value) }
    meta.send(:define_method, :relay, engine)
  end

  # The party: an Eevee, a Charizard with its four moves, and an egg.
  def party
    [Mon.new("Eevee", 12, :NORMAL, nil, nil, 1, ["Tackle", "Tail Whip"], "Run Away", false),
     Mon.new("Charizard", 36, :FIRE, :FLYING, "Charcoal", 0, ["Flamethrower", "Air Slash", "Earthquake", "Roost"],
             "Blaze", false),
     Mon.new("Egg", 1, :NORMAL, nil, nil, 2, ["Tackle"], "Run Away", true)]
  end

  # Eevee's card as said: name, type, level, no item, sex sign, its two moves and its ability.
  def eevee_card
    "Eevee, #{t(:pc_types, :t => 'Normal')}, Lv: 12, NO ITEM, ♀, Tackle, Tail Whip, Run Away"
  end

  # The Spanish text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end
end
