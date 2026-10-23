# Pokemon Z's damage numbers (PokeBattle_Scene#pbShowDamageNumber, shown while the "Mostrar daño" option is on): the
# number painted over a Pokemon whose hp changes, said where it is not the hp its bar loses, which the core says; with
# the numbers on, the core says a foe's change in hit points too.
module PokeAccess
  module ZDamage
    # True while Mostrar daño shows the numbers (0, also where the game's options do not hold the setting).
    def self.shown?
      (($PokemonSystem.numeritos rescue 0) || 0).to_i == 0
    end

    # True where a battler's battle scene paints damage numbers and they are shown.
    def self.painted_over?(b)
      scene = (b.battle.scene rescue nil)
      scene.respond_to?(:pbShowDamageNumber) && shown?
    end

    # The number pbShowDamageNumber paints (the move's whole damage where the hit passes one, else the hp change),
    # or nil while the option hides it or when it is the hp the bar loses.
    def self.painted(pkmn, oldhp, total)
      return nil unless shown?
      diff = (pkmn.hp - oldhp rescue 0).to_i
      amount = (total.to_i != 0) ? total.to_i : diff
      amount.abs == diff.abs ? nil : amount.abs
    end

    # Says the painted number after the hp line, where painted gives one.
    def self.say(pkmn, oldhp, total)
      n = painted(pkmn, oldhp, total)
      PokeAccess.speak(PokeAccess::I18n.t(:zdmg_number, :n => n), false) if n
    end
  end
end

PokeAccess::Game.define("pokemon_z") do
  before("PokeBattle_Scene", :pbShowDamageNumber, :optional => true) do |_scene, args|
    PokeAccess::ZDamage.say(args[0], args[1], args[4])
  end
  override("PokeAccess::Battle", :foe_change_painted?) do |_mod, original, args|
    PokeAccess::ZDamage.painted_over?(args[0]) || original.call
  end
end
