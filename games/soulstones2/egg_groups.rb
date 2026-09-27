# The egg groups Soulstones 2's Enhanced UI draws on the memo page, picked as pbDisplayEggGroups does: Undiscovered
# for an egg, a shadow or celestial Pokemon or Battle Bond; Unknown for a genderless one but Ditto; else its groups.
module PokeAccess
  module SS2EggGroups
    def self.text(pk)
      noeggs = (pk.egg? rescue false) || (pk.shadowPokemon? rescue false) || (pk.celestial? rescue false) ||
               (pk.hasAbility?(:BATTLEBOND) rescue false)
      groups = noeggs ? [:Undiscovered] : ((pk.species_data.egg_groups rescue nil) || [])
      genderless = (pk.genderless? rescue false) && !(pk.isSpecies?(:DITTO) rescue false)
      names = if genderless && !groups.include?(:Undiscovered)
                [PokeAccess::I18n.t(:egg_group_unknown)]
              else
                groups.uniq.map { |g| (GameData::EggGroup.get(g).name rescue g.to_s) }
              end
      names.empty? ? nil : PokeAccess::I18n.t(:sum_egg_groups, :g => names.join(", "))
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  override("PokeAccess::SummaryGameData", :memo_extras) do |_mod, original, args|
    (original.call || []) + [PokeAccess::SS2EggGroups.text(args[0])].compact
  end
end
