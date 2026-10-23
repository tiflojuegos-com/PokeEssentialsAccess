# Realidea's loot box (games/realidea/gacha.rb): each prize's rarity, from the game's own tier lists, said queued just
# ahead of the prize's message while the box is open, and never once it has closed.

# The game's prize handlers: each says its "obtained" message through the dialogue reader, as the game's messages do.
module Kernel
  def self.pbReceiveItem(item, _quantity = 1)
    PokeAccess.say_dialogue("¡Has obtenido el objeto #{item}!")
    true
  end
end

def pbAddPokemon(pokemon, _level = nil, _seeform = true)
  PokeAccess.say_dialogue("¡Tester ha obtenido un #{pokemon}!")
  true
end

# The loot box (LootBox), down to its draw: each prize handed over in turn, a Pokémon by its symbol, an item by its id.
class LootBox
  def initialize(draws); @draws = draws; end

  def pbStartMainScene
    @draws.each { |d| d.is_a?(Symbol) ? pbAddPokemon(d) : Kernel.pbReceiveItem(d) }
  end
end

gacha = File.join(Harness::ROOT, "games", "realidea", "gacha.rb")
eval(Harness.source(gacha), TOPLEVEL_BINDING, gacha)

class RealideaGachaTest < PokeAccessTest
  # The game's four tier lists, as its "Ver probabilidad" names them.
  TIERS = { :COMUNES => [101, 102, 103], :RAROS => [201, 202, 203], :LEGENDARIOS => [301, 302],
            :EPICOS => [401, 402] }

  test "names an item's rarity from the game's own tier lists" do
    with_tiers(TIERS) do
      { 101 => "Común", 202 => "Raro", 301 => "Legendario", 402 => "Épico" }.each do |item, tier|
        assert_equal tier, PokeAccess::ReaGacha.tier_of(item), "item #{item}"
      end
    end
  end

  test "names no rarity for an item in none of the lists" do
    with_tiers(TIERS) { assert_nil PokeAccess::ReaGacha.tier_of(999) }
  end

  test "skips a tier list the game lacks or keeps as no list" do
    with_tiers(:COMUNES => [101], :RAROS => { 201 => true }) do
      assert_equal "Común", PokeAccess::ReaGacha.tier_of(101), "the list the game keeps"
      assert_nil PokeAccess::ReaGacha.tier_of(201), "a hash is not a tier list"
      assert_nil PokeAccess::ReaGacha.tier_of(401), "a list the game lacks"
    end
  end

  test "says each prize's rarity queued just ahead of its message while the box is open" do
    with_tiers(TIERS) { LootBox.new([201, :MISDREAVUS, 999, 401]).pbStartMainScene }
    assert_equal [["Raro", false], ["¡Has obtenido el objeto 201!", false],
                  ["Pokémon", false], ["¡Tester ha obtenido un MISDREAVUS!", false],
                  ["¡Has obtenido el objeto 999!", false],
                  ["Épico", false], ["¡Has obtenido el objeto 401!", false]],
                 SpeakCapture.log,
                 "a Pokémon is its own tier, and an item in no list goes without one"
  end

  test "once the box has closed, a prize handed over elsewhere keeps its message to itself" do
    with_tiers(TIERS) do
      LootBox.new([202]).pbStartMainScene
      SpeakCapture.clear
      Kernel.pbReceiveItem(102)
      pbAddPokemon(:LEAFEON)
    end
    assert_equal [["¡Has obtenido el objeto 102!", false], ["¡Tester ha obtenido un LEAFEON!", false]], SpeakCapture.log
  end

  test "a box that fails partway through its draw still closes" do
    draws = Enumerator.new do |y|
      y << 203
      raise ArgumentError, "the box broke"
    end
    with_tiers(TIERS) do
      assert_raises(ArgumentError) { LootBox.new(draws).pbStartMainScene }
      SpeakCapture.clear
      Kernel.pbReceiveItem(103)
    end
    assert_equal [["¡Has obtenido el objeto 103!", false]], SpeakCapture.log
  end

  private

  # Runs the block with exactly these tier lists defined as the game's constants (a list left out is absent), the
  # constants as they were put back afterwards.
  def with_tiers(lists)
    names = TIERS.keys
    saved = names.select { |n| Object.const_defined?(n) }.map { |n| [n, Object.const_get(n)] }
    names.each { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
    lists.each { |n, list| Object.const_set(n, list) }
    yield
  ensure
    names.each { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
    saved.each { |n, list| Object.const_set(n, list) }
  end
end
