module PokeAccess
  # The BetterRegionMap addon (class BetterRegionMap), which the two Infinite Fusion games install in place
  # of the standard region map. Not a variant of PokemonRegionMapScene: a class of its own, with its own
  # loop, its own cursor in $PokemonGlobal.regionMapSel and no pbGetMapLocation, so none of the region-map
  # hooks bind to it.
  #
  # It never shows up in Hooks.missing either, because the CLASS the mod hooks does exist in those games --
  # the addon simply redefines the global pbShowMap to open this one instead. That is the failure a
  # capability gate cannot see, and the reason this file names the addon rather than a version. In core,
  # like the HUD text writer, because a reader shared by two games belongs to neither profile.
  module BetterMap
    # The town_map.dat row under the cursor, or nil. Each row is [x, y, name, poi, map_id, map_x, map_y].
    # One copy exposes the lookup as a method and the other keeps it inline, so it is asked for first.
    def self.location(scene, x, y)
      return (scene.find_location_at_position(x, y) rescue nil) if scene.respond_to?(:find_location_at_position)
      data = PokeAccess.ivar(scene, :@data)
      rows = data.is_a?(Array) ? data[2] : nil
      return nil unless rows.is_a?(Array)
      rows.find { |e| e[0] == x && e[1] == y }
    rescue StandardError
      nil
    end

    # The cursor's square, from the global the screen keeps it in.
    def self.cursor(_scene)
      sel = ($PokemonGlobal.regionMapSel rescue nil)
      (sel.is_a?(Array) && sel.length >= 2) ? [sel[0].to_i, sel[1].to_i] : nil
    end

    # Whether the screen drew a fly icon on this square. @spots is the set the constructor builds, and it
    # already applies the game's own rules -- visited maps, and the fly-anywhere override this screen has
    # and the standard one does not -- so asking it beats recomputing them.
    def self.fly_here?(scene, x, y)
      spots = PokeAccess.ivar(scene, :@spots)
      spots.is_a?(Hash) && !spots[[x, y]].nil?
    end

    # The line for the focused square: the place, its point of interest, and whether it can be flown to.
    # A square with no place is named by its coordinates -- the cursor DID move, and the screen shows that
    # even when it has no name to put under it.
    def self.square_text(scene, x, y)
      loc = location(scene, x, y)
      name = loc ? PokeAccess.clean(loc[2].to_s).to_s.strip : ""
      parts = []
      parts.push(name.empty? ? PokeAccess::I18n.t(:brm_square, :x => x, :y => y) : name)
      poi = loc ? PokeAccess.clean(loc[3].to_s).to_s.strip : ""
      parts.push(poi) unless poi.empty?
      parts.push(PokeAccess::I18n.t(:brm_fly)) if fly_here?(scene, x, y)
      parts.join(", ")
    end

    # Speaks the focused square when it changes. update_text is the screen's own paint of that line, so it
    # fires once per square and once on opening.
    #
    # It also marks the bottom-bar slot with what it just said: these games keep a MapBottomSprite that
    # repeats the place name a frame later, and an identical line spoken twice cuts the first one off.
    def self.read(scene)
      xy = cursor(scene)
      return unless xy
      t = PokeAccess::Cursor.on_change(scene, :better_map, xy) { square_text(scene, xy[0], xy[1]) }
      return if t.nil? || t.empty?
      PokeAccess.speak(t, true)
      PokeAccess::Cursor.changed?(nil, :regionmap, PokeAccess.clean(t))
    rescue StandardError
      nil
    end

    # The region's name, said once when the screen opens: the screen paints it at the top and never
    # changes it, so repeating it on every cursor move would be noise.
    def self.region_name(scene)
      r = PokeAccess.ivar(scene, :@region)
      return nil if r.nil?
      n = (pbGetMessage(MessageTypes::RegionNames, r) rescue nil)
      (n && !n.to_s.strip.empty?) ? PokeAccess.clean(n.to_s).to_s.strip : nil
    rescue StandardError
      nil
    end

    # Every square the map has a row for: the candidate list the fly jump searches.
    def self.points(scene)
      data = PokeAccess.ivar(scene, :@data)
      rows = data.is_a?(Array) ? data[2] : nil
      rows.is_a?(Array) ? rows.map { |e| [e[0], e[1]] } : []
    rescue StandardError
      []
    end

    # Places the cursor and repaints, which is also what makes the reader above speak the new square.
    def self.move(scene, x, y)
      scene.move_cursor_to(x, y)
      scene.update_text
    end
  end
end

# By SHAPE, like every other cursor provider: move_cursor_to plus this screen's own healing-spot lookup is
# a pair no other region map in the catalogue has.
PokeAccess::TownMap.register(
  "better_region_map",
  lambda { |s| s.respond_to?(:move_cursor_to) && s.respond_to?(:update_text) && s.respond_to?(:pbGetHealingSpot) },
  lambda { |s| PokeAccess::BetterMap.cursor(s) },
  lambda { |s, x, y| PokeAccess::BetterMap.move(s, x, y) },
  lambda { |s| PokeAccess::BetterMap.points(s) },
  lambda { |s| (PokeAccess.ivar(s, :@spots) || {}).keys }
)

# The paint of the line under the cursor. BOTH names are bound, because the two copies reach it by
# different routes: update_text resolves the square itself and then delegates, and one copy's cursor
# animation calls the delegate DIRECTLY once per half-step, so binding only the outer one leaves the map
# speaking at open and silent while the player sweeps it. Cursor dedups the square, so the copy that goes
# through both fires once.
["update_text", "update_text_at_location"].each do |m|
  PokeAccess::Hooks.after_hook("BetterRegionMap", m.to_sym, :optional => true) { |scene, _r, _a| PokeAccess::BetterMap.read(scene) }
end

# The opening read hangs off main and not off the constructor, in both copies, because of the ORDER the
# constructor runs in: it paints the text line, THEN builds the fly points, THEN places the cursor on the
# player -- and never repaints. So the line on screen when the map opens describes the square the cursor
# was on last time, not the one it is on now. Reading at the top of main gives the square the player is
# actually standing on, which is what every arrow from there is relative to.
#
# main is also the screen's own loop, so this is where the scene has to be held for the fly jump: nothing
# else pumps input while it runs.
PokeAccess::Hooks.before_hook("BetterRegionMap", :main, :optional => true) do |scene, _a|
  PokeAccess::TownMap.opened(scene)
  n = PokeAccess::BetterMap.region_name(scene)
  PokeAccess.speak(n, false) if n
  PokeAccess::BetterMap.read(scene)
end

PokeAccess::Hooks.after_hook("BetterRegionMap", :dispose, :optional => true) do |scene, _r, _a|
  PokeAccess::TownMap.closed(scene)
  PokeAccess::Cursor.reset(scene, :better_map)
end
