# Royal's damage numbers (its Damage Number Indicator, shown while the "Indicador Daño" option is on): the hit points a
# battler loses or gains, painted over it, so the core says a foe's change in hit points too; a hit paints the damage
# the move computed where it passes the hit points taken (a knockout), said after the hp line.
module PokeAccess
  module RoyalDamage
    # True while the indicator is active and Indicador Daño shows the numbers (0).
    def self.shown?
      (DamageNumberSettings::ACTIVE && $PokemonSystem.damage_numbers == 0) rescue false
    end

    # The damage pbHitAndHPLossAnimation paints over a battler hit from old_hp where it is not the hit points taken,
    # which the hp line says: the move's computed damage past them; nil while the numbers are hidden.
    def self.painted(battler, old_hp)
      return nil unless battler && shown?
      taken = old_hp.to_i - battler.hp.to_i
      calc = (battler.damageState.calcDamage rescue 0).to_i
      (taken > 0 && calc > taken) ? calc : nil
    end

    # Says, queued, the damage painted over each hit target ([battler, old hp, effectiveness]) that painted gives.
    def self.say(targets)
      (targets || []).each do |data|
        n = data.is_a?(Array) ? painted(data[0], data[1]) : nil
        PokeAccess.speak(PokeAccess::I18n.t(:zdmg_number, :n => n), false) if n
      end
    end
  end
end

PokeAccess::Game.define("royal") do
  override("PokeAccess::Battle", :foe_change_painted?) do |_mod, original, _args|
    PokeAccess::RoyalDamage.shown? || original.call
  end
  before("Battle::Scene", :pbHitAndHPLossAnimation, :optional => true) do |_scene, args|
    PokeAccess::RoyalDamage.say(args[0])
  end
end
