# Realidea's loot box (LootBox): each prize's rarity, shown only as a frame, said queued before the game's
# "obtained" message. Tiers are the game's lists, named as its "Ver probabilidad" does; a Pokémon is the fifth.
module PokeAccess
  module ReaGacha
    TIERS = [["COMUNES", "Común"], ["RAROS", "Raro"], ["LEGENDARIOS", "Legendario"], ["EPICOS", "Épico"]]

    # The rarity of an item prize, from the game's own tier lists; nil for an item in none of them.
    def self.tier_of(item)
      TIERS.each do |const, name|
        list = PokeAccess.const_at(const)
        return name if list.is_a?(Array) && list.include?(item)
      end
      nil
    end

    # Marks the loot box open or shut; the prize hooks speak only while it is open.
    def self.open=(v); @open = v; end
    def self.open?; @open ? true : false; end
  end
end

PokeAccess::Game.define("realidea") do
  around("LootBox", :pbStartMainScene, :optional => true) do |_s, nxt, _a|
    PokeAccess::ReaGacha.open = true
    begin
      nxt.call
    ensure
      PokeAccess::ReaGacha.open = false
    end
  end

  kernel("pbReceiveItem", :before) do |args, _r|
    t = PokeAccess::ReaGacha.open? ? PokeAccess::ReaGacha.tier_of(args[0]) : nil
    PokeAccess.speak(t, false) if t
  end

  kernel("pbAddPokemon", :before) do |_args, _r|
    PokeAccess.speak("Pokémon", false) if PokeAccess::ReaGacha.open?
  end
end
