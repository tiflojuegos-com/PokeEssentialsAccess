module PokeAccess
  # The BetterRegionMap addon, which replaces the standard region map through pbShowMap: a class of its own with
  # its own loop and its cursor in $PokemonGlobal.regionMapSel, which none of the region-map hooks reach.
  module BetterMap
    # The town_map.dat row at (x, y), [x, y, name, poi, map_id, map_x, map_y], or nil; through the scene's own
    # lookup where the copy has one.
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

    # Whether the screen drew a fly icon on this square: in @spots, on a map opened to fly (@can_fly), since the
    # quest map reuses @spots for its quests.
    def self.fly_here?(scene, x, y)
      return false unless PokeAccess.ivar(scene, :@can_fly)
      spots = PokeAccess.ivar(scene, :@spots)
      spots.is_a?(Hash) && !spots[[x, y]].nil?
    end

    # The square the player's "you are here" icon is drawn on: the sprite's position less the map's scroll, back to
    # the tile it centres on; nil while the screen draws no icon.
    def self.player_square(scene)
      win = PokeAccess.ivar(scene, :@window)
      spr = (win["player"] rescue nil)
      return nil unless spr && (spr.bitmap rescue nil) && (spr.visible rescue true) != false
      tw = (BetterRegionMap::TileWidth rescue 16.0).to_f
      th = (BetterRegionMap::TileHeight rescue 16.0).to_f
      [((spr.x - (win.x rescue 0) - tw / 2) / tw).round, ((spr.y - (win.y rescue 0) - th / 2) / th).round]
    rescue StandardError
      nil
    end

    # The focused square's parts: its place (or its coordinates), from medium its point of interest, whether it can
    # be flown to and whether the player's icon is on it; a profile whose copy paints more on the square overrides it.
    def self.square_parts(scene, x, y)
      loc = location(scene, x, y)
      name = loc ? PokeAccess.clean(loc[2].to_s) : ""
      parts = [[name.empty? ? PokeAccess::I18n.t(:brm_square, :x => x, :y => y) : name, :brief]]
      poi = loc ? PokeAccess.clean(loc[3].to_s) : ""
      parts.push([poi, :medium]) unless poi.empty?
      parts.push([PokeAccess::I18n.t(:brm_fly), :brief]) if fly_here?(scene, x, y)
      parts.push([PokeAccess::I18n.t(:rmap_you), :brief]) if player_square(scene) == [x, y]
      parts
    end

    # The focused square's line at the map square reading's level; the info key keeps the whole.
    def self.square_text(scene, x, y)
      PokeAccess::Verbosity.info_line(:map_square, square_parts(scene, x, y))
    end

    # Speaks the focused square when it changes, only once main has opened the screen (the constructor paints
    # too early); marked so the bottom bar's repeat is not said. interrupt false for the opening read.
    def self.read(scene, interrupt = true)
      return unless PokeAccess::TownMap.open_scene.equal?(scene)
      xy = cursor(scene)
      return unless xy
      t = PokeAccess::Cursor.on_change(scene, :better_map, xy) { square_text(scene, xy[0], xy[1]) }
      return if t.nil? || t.empty?
      PokeAccess::RegionMap.speak_marked(t, interrupt)
    rescue StandardError
      nil
    end

    # The region's name, said once as the screen opens.
    def self.region_name(scene)
      r = PokeAccess.ivar(scene, :@region)
      return nil if r.nil?
      n = (pbGetMessage(MessageTypes::RegionNames, r) rescue nil)
      (n && !n.to_s.strip.empty?) ? PokeAccess.clean(n.to_s) : nil
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

# Detected by shape (move_cursor_to, update_text and pbGetHealingSpot); the fly places are @spots only on a map
# opened to fly, as for the fly mark.
PokeAccess::TownMap.register(
  "better_region_map",
  lambda { |s| s.respond_to?(:move_cursor_to) && s.respond_to?(:update_text) && s.respond_to?(:pbGetHealingSpot) },
  lambda { |s| PokeAccess::BetterMap.cursor(s) },
  lambda { |s, x, y| PokeAccess::BetterMap.move(s, x, y) },
  lambda { |s| PokeAccess::BetterMap.points(s) },
  lambda { |s| PokeAccess.ivar(s, :@can_fly) ? (PokeAccess.ivar(s, :@spots) || {}).keys : [] }
)

# The paint of the line under the cursor, bound by both names since one copy's cursor animation calls
# update_text_at_location directly; the square is deduped, so a call through both speaks once.
["update_text", "update_text_at_location"].each do |m|
  PokeAccess::Hooks.after_hook("BetterRegionMap", m.to_sym, :optional => true) { |scene, _r, _a| PokeAccess::BetterMap.read(scene) }
end

# The opening read, before main: the constructor paints the line before it places the cursor on the player.
# main is also the screen's loop, so the scene is held there for the fly jump.
PokeAccess::Hooks.before_hook("BetterRegionMap", :main, :optional => true) do |scene, _a|
  PokeAccess::TownMap.opened(scene)
  PokeAccess::Cursor.reset(scene, :better_map)
  n = PokeAccess::BetterMap.region_name(scene)
  PokeAccess.speak(n, false) if n
  PokeAccess::BetterMap.read(scene, false)
end

PokeAccess::Hooks.after_hook("BetterRegionMap", :dispose, :optional => true) do |scene, _r, _a|
  PokeAccess::TownMap.closed(scene)
  PokeAccess::Cursor.reset(scene, :better_map)
  PokeAccess::Info.clear_text
end

PokeAccess::Verbosity.define_reading(:map_square, :vb_map_square, :vbh_map_square)
