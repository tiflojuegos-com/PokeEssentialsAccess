module PokeAccess
  # Chai-Tao's Easy Badge Case (PokemonBadgecase_Scene, opened from the Pokegear): one picture of each of the eight
  # badges the player holds, nothing written. Said on opening, and kept for the info key, as the badges held by the names
  # the game gives the Fancy Badges ceremony (FANCY_BADGE_NAMES, FancyBadges::NAMES), or their count where it has none.
  module BadgeCase
    # The badges held, by index, as the case draws them: $Trainer.badges[i] true for i 0 to 7.
    def self.held
      badges = (PokeAccess::Engine.player.badges rescue nil)
      return [] unless badges.respond_to?(:[])
      (0...8).select { |i| badges[i] == true }
    end

    # The opening line: the screen's name, then the badges held.
    def self.line
      ids = held
      names = PokeAccess.const_at("FANCY_BADGE_NAMES") || PokeAccess.const_at("FancyBadges::NAMES")
      named = names.is_a?(Array) ? ids.map { |i| names[i] } : []
      listed = named.compact.map { |n| PokeAccess.clean(n.to_s) }
      badges = if !ids.empty? && listed.length == ids.length
                 PokeAccess::I18n.t(:tcard_badge_list, :list => listed.join(", "))
               else
                 PokeAccess::I18n.t(:tr_badges, :n => ids.length)
               end
      text = "#{PokeAccess::I18n.t(:badgecase_title)}. #{badges}"
      PokeAccess::Info.set_info(:text, text)
      text
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.read_on_open("PokemonBadgecase_Scene", :pbStartScene, :optional => true, :hook_container => true) do |_scene|
  PokeAccess::BadgeCase.line
end
PokeAccess::Hooks.clear_info_on("PokemonBadgecase_Scene", :pbEndScene)
