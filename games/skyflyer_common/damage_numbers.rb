module PokeAccess
  # Sky's Damage Number Indicator (048_UI/037_Damage_Number, Royal and World Frontier): while
  # DamageNumberSettings::ACTIVE and the "Indicador Daño" option shows them, the hit points a battler loses or gains
  # float over it, so a foe's change is said in hit points; a hit paints the damage the move computed where it passes
  # the hit points taken (a knockout).
  module SkyDamageNumbers
    # True while the indicator paints the numbers (the option's value 0).
    def self.shown?
      return false unless defined?(::DamageNumberSettings) && ::DamageNumberSettings::ACTIVE
      ($PokemonSystem.damage_numbers == 0) rescue false
    end

    # The damage pbHitAndHPLossAnimation paints over a battler hit from old_hp past the hit points it took, which the
    # hp line says: the move's computed damage; nil while the numbers are hidden or the hit points covered the hit.
    def self.painted(battler, old_hp)
      return nil unless battler && shown?
      taken = old_hp.to_i - battler.hp.to_i
      calc = (battler.damageState.calcDamage rescue 0).to_i
      (taken > 0 && calc > taken) ? calc : nil
    end

    # Says, queued, the damage painted over each hit target ([battler, old hp, ...]) past the hit points it took.
    def self.say(targets)
      (targets || []).each do |data|
        n = data.is_a?(Array) ? painted(data[0], data[1]) : nil
        PokeAccess.speak(PokeAccess::I18n.t(:zdmg_number, :n => n), false) if n
      end
    end
  end
end

PokeAccess::Game.define("skyflyer_common") do
  override("PokeAccess::Battle", :foe_change_painted?) do |_mod, original, _args|
    PokeAccess::SkyDamageNumbers.shown? || original.call
  end
  before("Battle::Scene", :pbHitAndHPLossAnimation, :optional => true) do |_scene, args|
    PokeAccess::SkyDamageNumbers.say(args[0])
  end
end
