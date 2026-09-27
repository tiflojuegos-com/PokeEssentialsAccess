# Pokemon Z's damage numbers (PokeBattle_Scene#pbShowDamageNumber, shown while the "Mostrar daño" option is on): the
# number painted over a Pokemon whose hp changes, said where it is not the hp its bar loses, which the core says.
module PokeAccess
  module ZDamage
    # The number pbShowDamageNumber paints (the move's whole damage where the hit passes one, else the hp change),
    # or nil while the option hides it or when it is the hp the bar loses.
    def self.painted(pkmn, oldhp, total)
      return nil unless (($PokemonSystem.numeritos rescue 0) || 0).to_i == 0
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
end
