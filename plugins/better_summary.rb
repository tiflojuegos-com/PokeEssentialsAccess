module PokeAccess
  # Better Summary's ability page (the special button), painted outside drawPage: the ability, its description,
  # the sex sign and the held item, from the Pokemon showAbilityDescription is handed.
  module BetterSummary
    def self.ability(pkmn)
      a = (pkmn.ability rescue nil)
      return unless a
      name = PokeAccess.clean((a.name rescue "").to_s)
      return if name.empty?
      desc = PokeAccess.clean((a.description rescue "").to_s)
      PokeAccess.speak(PokeAccess::Util.join_parts([name, desc] + extras(pkmn)), true)
    rescue StandardError
      nil
    end

    # The sex and the held item as the page writes them: the item line is always painted, "none" included.
    def self.extras(pkmn)
      out = []
      sex = (PokeAccess::Party.gender_glyph(pkmn) rescue nil)
      out.push(sex) if sex
      it = ((pkmn.hasItem? rescue false) ? (pkmn.item.name rescue nil) : nil)
      out.push(PokeAccess::I18n.t(:sum_item, :i => it || PokeAccess::I18n.t(:bs_no_item)))
      out
    rescue StandardError
      []
    end
  end
end

# Forgets the page underneath as the ability page opens, so its redraw on closing is read.
PokeAccess::Hooks.before_hook("PokemonSummary_Scene", :showAbilityDescription, :optional => true) do |scene, args|
  PokeAccess::Summary.forget_page(scene)
  PokeAccess::BetterSummary.ability(args[0])
end
