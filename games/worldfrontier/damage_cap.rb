# World Frontier's cap on Sky's damage numbers (Scripts menores, 010_Damage_numbers_tope_ps): the number a hit paints
# never passes the hit points the battler had, and a hit its substitute takes paints what the doll lost;
# skyflyer_common's SkyDamageNumbers says what this answers.
module PokeAccess
  module WFDamageCap
    # What a hit on battler from old_hp paints past the hit points taken, or nil: the damage the move computed, no
    # further than the hit points it had; for a hit its substitute took, what the doll lost.
    def self.painted(battler, old_hp)
      state = battler.damageState
      taken = old_hp.to_i - battler.hp.to_i
      lost = state.substitute ? state.hpLost.to_i : 0
      return (lost > 0 ? lost : nil) if taken <= 0
      shown = [[state.calcDamage.to_i, taken].max, lost > 0 ? lost : old_hp.to_i].min
      shown > taken ? shown : nil
    end
  end
end

PokeAccess::Game.define("worldfrontier") do
  override("PokeAccess::SkyDamageNumbers", :painted) do |_mod, original, args|
    if args[0] && PokeAccess::SkyDamageNumbers.shown?
      (PokeAccess::WFDamageCap.painted(args[0], args[1]) rescue nil)
    else
      original.call
    end
  end
end
