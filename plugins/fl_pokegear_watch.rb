module PokeAccess
  # FL's Pokegear Watch, which paints the game's clock (@date_string, from pbGetTimeNow) over the Pokegear menu, the
  # plain one and the themed one: said on opening after the focused option, and kept on the info key as it ticks.
  module PokegearWatch
    # The clock as painted, without the seconds, or nil when the watch has painted nothing.
    def self.time_text(scene)
      t = PokeAccess.ivar(scene, :@date_string)
      return nil if t.nil? || t.to_s.strip.empty?
      PokeAccess.clean(t.to_s.sub(/(\d{1,2}:\d{2}):\d{2}/, '\1'))
    end

    # Points the info key at the clock each time the minute shown changes.
    def self.ticked(scene)
      t = time_text(scene)
      PokeAccess::Info.set_info(:text, t) if t && PokeAccess::Cursor.changed?(scene, :pgwatch_info, t)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says the clock once the menu has opened, queued behind the focused option it reads first.
    def self.opened(scene)
      t = time_text(scene)
      return unless t
      PokeAccess::Info.set_info(:text, t)
      PokeAccess.speak(t, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("PokemonPokegear_Scene", :pbStartScene, :optional => true) do |scene, nxt, _a|
  r = nxt.call
  PokeAccess::PokegearWatch.opened(scene)
  r
end
PokeAccess::Hooks.around_hook("PokemonPokegearTheme_Scene", :pbStartScene, :optional => true) do |scene, nxt, _a|
  r = nxt.call
  PokeAccess::PokegearWatch.opened(scene)
  r
end

# refresh_date runs every frame and answers true only when it repainted, once a second.
PokeAccess::Hooks.after_hook("PokemonPokegear_Scene", :refresh_date, :optional => true) do |scene, result, _a|
  PokeAccess::PokegearWatch.ticked(scene) if result
end
PokeAccess::Hooks.after_hook("PokemonPokegearTheme_Scene", :refresh_date, :optional => true) do |scene, result, _a|
  PokeAccess::PokegearWatch.ticked(scene) if result
end
