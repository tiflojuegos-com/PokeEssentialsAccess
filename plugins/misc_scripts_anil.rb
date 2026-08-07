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
      PokeAccess::Cursor.announce(scene, :starter_region, t, true) { t }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("StarterMenu_Scene", :pbRedrawList, :optional => true) do |scene, _r, _a|
  PokeAccess::StartersV21.read(scene)
end

# The opening read belongs here and not to the redraw the constructor ends with: the screen's own caller
# puts a pbMessage between the two, and the dialogue reader cuts whatever was said before it. The slot is
# cleared first because that cut read already recorded the region.
PokeAccess::Hooks.before_hook("StarterMenu_Scene", :pbSelectElement, :optional => true) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :starter_region)
  PokeAccess::StartersV21.read(scene)
end
