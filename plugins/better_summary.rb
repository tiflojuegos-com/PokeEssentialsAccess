module PokeAccess
  # Better Summary: adds a full-screen ability page to the summary, opened with the special button.
  #
  # It bypasses drawPage entirely -- it paints straight onto the overlay bitmap -- so not one of the summary
  # hooks fires. There is no cursor on it either, so there is nothing to poll: the page is static and the
  # method that draws it is handed the Pokemon, which is all the reader needs.
  #
  # Besides the ability, the page paints the held item (or "none") and the sex symbol. Both copies do, and
  # both are worth saying: this page is entered from the MOVES page, where neither appears, so for a blind
  # player the held item exists nowhere else in the summary.
  module BetterSummary
    def self.ability(pkmn)
      a = (pkmn.ability rescue nil)
      return unless a
      name = PokeAccess.clean((a.name rescue "").to_s).to_s.strip
      return if name.empty?
      desc = PokeAccess.clean((a.description rescue "").to_s).to_s.strip
      PokeAccess.speak(PokeAccess::Util.join_parts([name, desc] + extras(pkmn)), true)
    rescue StandardError
      nil
    end

    # The sex and the held item as the page writes them: the item line is always painted, "none" included.
    def self.extras(pkmn)
      out = []
      sex = (PokeAccess::Party.gender_word(pkmn) rescue nil)
      g = (pkmn.gender rescue nil)
      out.push(sex) if sex && (g == 0 || g == 1)
      it = ((pkmn.hasItem? rescue false) ? (pkmn.item.name rescue nil) : nil)
      out.push(PokeAccess::I18n.t(:sum_item, :i => it || PokeAccess::I18n.t(:bs_no_item)))
      out
    rescue StandardError
      []
    end
  end
end

# Closing the page redraws the skills page underneath, and the summary reader dedups a page against the last
# one it spoke -- which is still that same skills page, because nothing replaced it while the ability page was
# up. Forgetting it here is what makes coming back say where you are instead of dropping the player onto a
# silent screen.
PokeAccess::Hooks.before_hook("PokemonSummary_Scene", :showAbilityDescription, :optional => true) do |scene, args|
  scene.instance_variable_set(:@access_page_text, nil) rescue nil
  PokeAccess::BetterSummary.ability(args[0])
end
