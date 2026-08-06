module PokeAccess
  # Zone banners / signs from the JessLetreros plugin: it replaces the standard signpost with a custom
  # LocationWindow whose initialize receives the place name, so reading that on creation voices every banner
  # the instant it appears. A profile that ships this plugin opts in with LocationBanner.define(game).
  # Queued, so it never cuts an entry cutscene's dialogue.
  module LocationBanner
    # Registers the LocationWindow reader for a game profile.
    def self.define(game)
      PokeAccess::Game.define(game) do
        after("LocationWindow", :initialize) do |_window, _result, args|
          # The plugin's own off switch. Its initialize returns immediately when jess_letreros_activo is set,
          # so events that suppress the banner (pb_jla) build the object and draw nothing -- and the hook,
          # which fires either way, announced a sign that is not on screen.
          name = ($game_temp.jess_letreros_activo rescue false) ? "" : args[0].to_s
          PokeAccess.speak(name, false) unless name.strip.empty?
        end
      end
    end
  end
end
