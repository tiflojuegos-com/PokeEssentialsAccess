module PokeAccess
  # Pathfinder, across water: for a target out of walking reach, the flood runs again with surfing allowed and each
  # tile keeps the shore the flood first pushed off from on its way there, the shore to walk to.
  module Pathfinder
    # Surfable water the flood may cross: the engine's surfable tags, less falling water, which only
    # Waterfall climbs and no route can ask for.
    def self.surf_water?(x, y)
      return false unless PokeAccess::Terrain.surfable_at?(x, y)
      k = PokeAccess::Terrain.kind(x, y)
      k != :waterfall && k != :waterfall_crest
    rescue StandardError
      false
    end

    # A surfing move walking cannot make, as a Step or nil: pushing off from a shore open toward the water, water to
    # water (falls included), or coming ashore on a tile open on the water side with nothing solid on it.
    def self.water_step(cx, cy, dir, lvl, wet)
      nx = cx + dir[0]; ny = cy + dir[1]; d = dir[2]
      return nil unless ($game_map.valid?(nx, ny) rescue false)
      return falls_step(nx, ny, d, lvl) if wet && falling_water?(nx, ny)
      if surf_water?(nx, ny)
        return nil unless wet || ($game_map.passable?(cx, cy, d) rescue false)
        return Step.new(nx, ny, lvl)
      end
      return nil unless wet
      return nil unless ($game_map.passable?(nx, ny, 10 - d) rescue false)
      return nil if solid_event_at?(nx, ny) || exit_step?(nx, ny, d)
      Step.new(nx, ny, lvl)
    end

    # Falling water met afloat: carried down from its crest, and climbed with Waterfall when the party may be
    # able to, each to the water past it.
    def self.falls_step(x, y, d, lvl)
      l = if d == 2
            PokeAccess::Terrain.kind(x, y) == :waterfall_crest ? fall_end(x, y, 1) : nil
          elsif d == 8 && PokeAccess::FieldMoves.can?(:WATERFALL) != false
            waterfall_ascent(x, y)
          end
      (l && surf_water?(l[0], l[1])) ? Step.new(l[0], l[1], lvl) : nil
    end

    # True if an event the player cannot walk through stands on (x,y).
    def self.solid_event_at?(x, y)
      ($game_map.events.values.any? do |e|
        e.x == x && e.y == y && !(e.through rescue false) && !e.character_name.to_s.empty?
      end) ? true : false
    rescue StandardError
      false
    end

    # The flood with surfing allowed, cached per player tile.
    def self.amphibious_set
      key = [($game_player.x rescue 0), ($game_player.y rescue 0), ($game_map.map_id rescue 0)]
      return @amph if @amph_key == key && @amph
      @amph_key = key
      @amph = with_level_kept { PokeAccess::Terrain.memoizing(held_terrain) { flood(true)[0] } }
    rescue StandardError
      {}
    end

    # The first launch on the way to (tx,ty) as [shore x, shore y, facing], or nil when surfing gets nowhere
    # near it, the player is already afloat, or the party is known not to be able to surf.
    def self.surf_plan(tx, ty)
      return nil if ($PokemonGlobal.surfing rescue false)
      return nil if PokeAccess::FieldMoves.can?(:SURF) == false
      return nil if PokeAccess::MapMeta.always_bicycle?(($game_map.map_id rescue 0))
      set = amphibious_set
      [[0, 0], [0, -1], [0, 1], [-1, 0], [1, 0]].each do |dx, dy|
        v = set[pkey(tx + dx, ty + dy)]
        return v if v.is_a?(Array)
      end
      nil
    rescue StandardError
      nil
    end

    # The route onto the shore to surf from toward (tx,ty) (surf_plan), cached per player tile and target; nil when
    # surfing does not reach it.
    def self.surf_launch(tx, ty)
      k = [($game_player.x rescue -1), ($game_player.y rescue -1), ($game_map.map_id rescue -1), tx, ty]
      return @surf_route if @surf_key == k
      @surf_key = k
      pl = surf_plan(tx, ty)
      @surf_route = pl ? find_path_onto(pl[0], pl[1]) : nil
    rescue StandardError
      nil
    end

    # The facing to push off in when the player stands on the shore planned for (tx,ty), else nil.
    def self.launch_dir(tx, ty)
      pl = surf_plan(tx, ty)
      (pl && pl[0] == ($game_player.x rescue nil) && pl[1] == ($game_player.y rescue nil)) ? pl[2] : nil
    end
  end
end
