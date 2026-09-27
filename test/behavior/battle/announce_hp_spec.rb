# announce_hp_change: a change is spoken once as a loss or a gain, the exact HP on the player's side (even index)
# and a percentage for a foe (odd index); no change and a nil old value speak nothing.
class TestBattler
  attr_accessor :hp, :totalhp, :index, :name

  # Builds a battler stub. index even = player side (exact HP), odd = foe side (percentage).
  def initialize(name, hp, totalhp, index)
    @name = name; @hp = hp; @totalhp = totalhp; @index = index
  end
end

Suite.define("battle: HP loss on the player's Pokemon reads exact HP") do
  pkmn = TestBattler.new("Bulba", 20, 44, 0)
  PokeAccess::Battle.announce_hp_change(pkmn, 30)
  spoke_once "the change is announced once", /Bulba/
  spoke "spoken as a loss", /#{Regexp.escape(PokeAccess::I18n.t(:bt_lose))}/
  spoke "reads the exact remaining HP", /#{Regexp.escape(PokeAccess::I18n.t(:bt_hp_exact, :hp => 20, :tot => 44))}/
end

Suite.define("battle: HP gain on a foe reads a percentage") do
  foe = TestBattler.new("Rattata", 50, 100, 1)
  PokeAccess::Battle.announce_hp_change(foe, 20)
  spoke "spoken as a gain", /#{Regexp.escape(PokeAccess::I18n.t(:bt_gain))}/
  spoke "reads a percentage, not the exact value", /#{Regexp.escape(PokeAccess::I18n.t(:bt_hp_pct, :n => 50))}/
  not_spoke "does not leak the exact foe HP", /#{Regexp.escape(PokeAccess::I18n.t(:bt_hp_exact, :hp => 50, :tot => 100))}/
end

Suite.define("battle: an unchanged HP says nothing") do
  pkmn = TestBattler.new("Char", 40, 40, 0)
  PokeAccess::Battle.announce_hp_change(pkmn, 40)
  silent "an unchanged HP says nothing"

  PokeAccess::Battle.announce_hp_change(pkmn, nil)
  silent "and so is a nil previous value, though by the rescue rather than by the guard"
end
