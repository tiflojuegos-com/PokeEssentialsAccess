module PokeAccess
  # Zone banners of the JessLetreros plugin, whose LocationWindow#initialize receives the place name: said, queued,
  # as the window is created. A profile that ships the plugin opts in with LocationBanner.define(game).
  module LocationBanner
    # Registers the LocationWindow reader for a game profile; silent while jess_letreros_activo is set, when the
    # plugin draws nothing.
    def self.define(game)
      PokeAccess::Game.define(game) do
        after("LocationWindow", :initialize) do |_window, _result, args|
          name = ($game_temp.jess_letreros_activo rescue false) ? "" : args[0].to_s
          PokeAccess.speak(name, false)
        end
      end
    end
  end
end
