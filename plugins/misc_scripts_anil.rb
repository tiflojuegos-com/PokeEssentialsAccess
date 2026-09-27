module PokeAccess
  # New-game starter selection (Misc Scripts plugin, StarterMenu_Scene): the focused region of @options_to_use
  # ([region_name, [starter ids]]) and its starters, on each pbRedrawList, after the title the menu paints.
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

    # Keeps the title the block paints (the menu's cursor_max_opcion) on the scene, for the opening read.
    def self.keep_title(scene)
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      scene.instance_variable_set(:@access_title, PokeAccess::PaintCapture.lines(pairs).join(". "))
      ret
    end

    # The opening read, after the caller's message: the painted title, then the focused region queued after it.
    def self.open(scene)
      title = PokeAccess.ivar(scene, :@access_title).to_s
      PokeAccess.speak(title, true) unless title.empty?
      PokeAccess::Cursor.reset(scene, :starter_region)
      t = text(scene)
      PokeAccess::Cursor.announce(scene, :starter_region, t, true, false) { t }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("StarterMenu_Scene", :pbRedrawList, :optional => true) do |scene, _r, _a|
  PokeAccess::StartersV21.read(scene)
end

PokeAccess::Hooks.around_hook("StarterMenu_Scene", :cursor_max_opcion, :optional => true) do |scene, nxt, _a|
  PokeAccess::StartersV21.keep_title(scene) { nxt.call }
end

# The opening read, taken after the caller's pbMessage that would cut the constructor's redraw, with the slot
# cleared since that redraw already recorded the region.
PokeAccess::Hooks.before_hook("StarterMenu_Scene", :pbSelectElement, :optional => true) do |scene, _a|
  PokeAccess::StartersV21.open(scene)
end
