module PokeAccess
  # Reborn's battle box (PokemonDataBox): with the switch Level_999 on, as the final battle at the New World Asylum
  # sets it, a foe's box paints Lv999 whatever its level.
  module RebornBattleBox
    # Whether a battler's box paints that level: a foe's, while the switch is on.
    def self.level_999?(b)
      on = ($game_switches[:Level_999] rescue false) ? true : false
      on && (b.index % 2) == 1
    rescue StandardError
      false
    end
  end
end

PokeAccess::Game.define("reborn") do
  override("PokeAccess::Battle", :shown_level) do |_mod, original, args|
    PokeAccess::RebornBattleBox.level_999?(args[0]) ? 999 : original.call
  end
end
