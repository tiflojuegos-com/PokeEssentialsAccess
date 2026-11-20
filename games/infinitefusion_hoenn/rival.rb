module PokeAccess
  # Hoenn's rival, the events the editor names HOENN_RIVAL (053_PIF_Hoenn/Rivals/Hoenn_Rival.rb), a quest tag after it on
  # route 104: named as the player chose at the rival's form, kept in variable 12 (VAR_RIVAL_NAME), or before that by the
  # game's default for the player's gender (get_default_rival_name: May beside a boy, Brendan beside a girl).
  module IF2Rival
    EVENT = /\AHOENN_RIVAL\b/
    NAME_VAR = 12

    # The rival's name for one of its events; nil for any other event, or while the game gives none.
    def self.name_of(ev)
      return nil unless EVENT.match(ev.name.to_s)
      chosen = $game_variables[NAME_VAR]
      return chosen.strip if chosen.is_a?(String) && !chosen.strip.empty?
      default = respond_to?(:get_default_rival_name, true) ? get_default_rival_name : nil
      default.is_a?(String) && !default.empty? ? default : nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  event_name { |ev| PokeAccess::IF2Rival.name_of(ev) }
end
