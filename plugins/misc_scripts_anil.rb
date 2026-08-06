module PokeAccess
  # New-game starter selection (Misc Scripts plugin, StarterMenu_Scene). A custom sprite menu
  # that scrolls a list of regions (@options_to_use, each [region_name, [starter ids]]) by
  # @index, with no command window, so it is otherwise mute. pbRedrawList runs on open and on
  # every cursor move, so the focused region and its three starters are read from there, deduped.
  module StartersV21
    # The focused region and its starters, e.g. "Starters of Kanto: Bulbasaur, Charmander, Squirtle".
    def self.text(scene)
      opts = PokeAccess.ivar(scene, :@options_to_use)
      idx  = PokeAccess.ivar(scene, :@index)
      return nil unless opts.is_a?(Array) && idx && opts[idx]
      region = opts[idx][0].to_s
      mons = ((opts[idx][1] || []).map { |s| s ? (GameData::Species.get(s).name rescue s.to_s) : nil }.compact)
      mons.empty? ? PokeAccess::I18n.t(:starter_region_only, :region => region) :
                    PokeAccess::I18n.t(:starter_region, :region => region, :mons => mons.join(", "))
    rescue StandardError
      nil
    end

    # Speaks the focused region when it changes.
    def self.read(scene)
      t = text(scene)
      return if t.nil? || t == PokeAccess.ivar(scene, :@access_starter_last)
      scene.instance_variable_set(:@access_starter_last, t)
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("StarterMenu_Scene", :pbRedrawList, :optional => true) do |scene, _r, _a|
  PokeAccess::StartersV21.read(scene)
end
