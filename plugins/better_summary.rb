module PokeAccess
  # Better Summary: adds a full-screen ability page to the summary, opened with the special button.
  #
  # It bypasses drawPage entirely -- it paints straight onto the overlay bitmap -- so not one of the summary
  # hooks fires and the page was silent from the moment it opened. There is no cursor on it either, so there
  # is nothing to poll: the whole content is the ability's name and its description, and the method that
  # draws the page is handed the Pokemon, which is all the reader needs.
  module BetterSummary
    def self.ability(pkmn)
      a = (pkmn.ability rescue nil)
      return unless a
      name = PokeAccess.clean((a.name rescue "").to_s).to_s.strip
      return if name.empty?
      desc = PokeAccess.clean((a.description rescue "").to_s).to_s.strip
      PokeAccess.speak(PokeAccess::Util.join_parts([name, desc]), true)
    rescue StandardError
      nil
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
