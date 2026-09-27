module PokeAccess
  # The region map's fly-jump (J/K/L/I): moves the cursor through a provider picked by the scene's shape, not its
  # class name (Arcky's plugin and the v21 rework share PokemonRegionMap_Scene); the last registered wins.
  module TownMap
    # provider: [name, handles?(scene), cursor(scene) -> [x,y], move(scene,x,y), points(scene) -> [[x,y]..],
    # flyable(scene) -> [[x,y]..] or nil]
    def self.providers; @providers ||= []; end

    # Registers a cursor provider; the last registered wins, so a profile overrides the built-ins.
    # param flyable only for a screen with its own flyable set, as a fly-anywhere mode draws more than fly_points
    def self.register(name, handles, cursor, move, points, flyable = nil)
      providers.push([name, handles, cursor, move, points, flyable])
    end

    # The provider that fits this scene, or nil when none does (no jump there).
    def self.provider_for(scene)
      providers.reverse.each { |p| return p if (p[1].call(scene) rescue false) }
      nil
    end

    # The cursor's [x, y], or nil when no provider handles the scene.
    def self.cursor(scene)
      p = provider_for(scene)
      p ? (p[2].call(scene) rescue nil) : nil
    end

    # Places the cursor. Returns whether it moved.
    def self.move(scene, x, y)
      p = provider_for(scene)
      return false unless p
      (p[3].call(scene, x, y); true) rescue false
    end

    # Every point on the map as [x, y] pairs, flyable or not (see fly_points).
    def self.points(scene)
      p = provider_for(scene)
      return [] unless p
      (p[4].call(scene) rescue []) || []
    end

    # The points the screen marks as flyable, as [x, y]: the provider's own set, else those with a healing spot
    # (pbGetHealingSpot) on a visited map.
    def self.fly_points(scene)
      p = provider_for(scene)
      own = (p && p[5]) ? (p[5].call(scene) rescue nil) : nil
      return own if own.is_a?(Array)
      out = []
      points(scene).each do |xy|
        spot = healing_spot(scene, xy)
        out.push(xy) if spot && visited?(spot)
      end
      out
    end

    # The healing spot for a map square, by (x, y) or, where the method takes the map data first, (map, x, y).
    def self.healing_spot(scene, xy)
      begin
        return scene.pbGetHealingSpot(xy[0], xy[1])
      rescue ArgumentError
        nil
      rescue StandardError
        return nil
      end
      (scene.pbGetHealingSpot(PokeAccess.ivar(scene, :@map), xy[0], xy[1]) rescue nil)
    end

    # Whether the destination's map has been visited; yes when the game keeps no such record.
    def self.visited?(spot)
      id = spot.is_a?(Array) ? spot[0] : nil
      return true if id.nil?
      v = ($PokemonGlobal.visitedMaps rescue nil)
      return true if v.nil?
      v[id] ? true : false
    rescue StandardError
      true
    end

    # Whether the jump is offered at all; a profile turns it off where the game has better (Arcky's Quick Fly list).
    def self.jump_enabled; @jump_enabled = true if @jump_enabled.nil?; @jump_enabled; end
    def self.jump_enabled=(v); @jump_enabled = v; end

    # The map scene on screen, or nil; while it is set, J/K/L/I jump instead of working the locator.
    def self.open_scene; @open; end

    def self.opened(scene)
      @open = scene
      @fly_cache = nil
    end

    def self.closed(_scene)
      @open = nil
      @fly_cache = nil
    end

    # The flyable points of the open scene, computed once per opening; a provider with its own set is asked every time
    # (its map may pan).
    def self.fly_cache(scene)
      p = provider_for(scene)
      return fly_points(scene) if p && p[5]
      @fly_cache ||= fly_points(scene)
    end

    # Jumps to the nearest flyable point in a direction; true when the cursor moved. The destination is not said
    # here: the scene's pbGetMapLocation reader says it next frame.
    def self.jump(scene, dir)
      return false unless scene && jump_enabled
      here = cursor(scene)
      return false unless here && here[0] && here[1]
      target = nearest(fly_cache(scene), here[0], here[1], dir)
      if target.nil?
        PokeAccess.speak(PokeAccess::I18n.t(:tm_no_fly), true)
        return false
      end
      move(scene, target[0], target[1])
    end

    # The nearest point strictly in one direction from (x, y), or nil; ties go to the smaller sideways drift.
    def self.nearest(candidates, x, y, dir)
      best = nil
      best_key = nil
      candidates.each do |cx, cy|
        along, across = case dir
          when :left  then [x - cx, (cy - y).abs]
          when :right then [cx - x, (cy - y).abs]
          when :up    then [y - cy, (cx - x).abs]
          when :down  then [cy - y, (cx - x).abs]
          else [0, 0]
        end
        next if along <= 0
        key = [along, across]
        if best_key.nil? || (key <=> best_key) < 0
          best = [cx, cy]
          best_key = key
        end
      end
      best
    end
  end
end

# Gen-6 vanilla and Arcky's plugin: the cursor is @mapX/@mapY, the points the raw @map[2] rows. The cursor sprite
# is moved too, by the scene's own formula, as the scene only repositions it on its animated path.
PokeAccess::TownMap.register(
  :classic,
  lambda { |s| !PokeAccess.ivar(s, :@mapX).nil? },
  lambda { |s| [PokeAccess.ivar(s, :@mapX), PokeAccess.ivar(s, :@mapY)] },
  lambda do |s, x, y|
    s.instance_variable_set(:@mapX, x)
    s.instance_variable_set(:@mapY, y)
    cur = PokeAccess.sprite(s, "cursor")
    bmp = (PokeAccess.sprite(s, "map").bitmap rescue nil)
    sw = (s.class::SQUAREWIDTH rescue nil)
    sh = (s.class::SQUAREHEIGHT rescue nil)
    if cur && bmp && sw && sh
      cur.x = -sw / 2 + (x * sw) + (Graphics.width - bmp.width) / 2
      cur.y = -sh / 2 + (y * sh) + (Graphics.height - bmp.height) / 2
    end
  end,
  lambda { |s| m = PokeAccess.ivar(s, :@map); (m && m[2] ? m[2] : []).map { |p| [p[0], p[1]] } }
)

# The v21+ UI rework: snake_case ivars, the sprite placed by the scene's point_x_to_screen_x helpers, and points
# in @map.point or, where the ivars came a version before the data, in the old @map[2].
PokeAccess::TownMap.register(
  :ui_rework,
  lambda { |s| !PokeAccess.ivar(s, :@map_x).nil? },
  lambda { |s| [PokeAccess.ivar(s, :@map_x), PokeAccess.ivar(s, :@map_y)] },
  lambda do |s, x, y|
    s.instance_variable_set(:@map_x, x)
    s.instance_variable_set(:@map_y, y)
    cur = PokeAccess.sprite(s, "cursor")
    if cur && s.respond_to?(:point_x_to_screen_x)
      cur.x = s.point_x_to_screen_x(x)
      cur.y = s.point_y_to_screen_y(y)
    end
  end,
  lambda do |s|
    m = PokeAccess.ivar(s, :@map)
    list = (m.respond_to?(:point) ? m.point : (m.is_a?(Array) ? m[2] : nil))
    (list || []).map { |p| [p[0], p[1]] }
  end
)

# The locator keys as jump directions while the map is up; the locator's driver does not run inside its loop.
PokeAccess::TownMap::DIRS = [[:prev, :left], [:next, :right], [:route, :up], [:where, :down]]

# Drops the open scene on a map change too, in case a close hook failed to bind and left the keys hijacked.
PokeAccess::Caches.register(:town_map_open) { PokeAccess::TownMap.closed(nil) }

PokeAccess::Keys.on_frame do
  scene = PokeAccess::TownMap.open_scene
  if scene && (PokeAccess::Keys.enabled rescue true) && (PokeAccess::Keys.focused? rescue true)
    PokeAccess::TownMap::DIRS.each do |sym, dir|
      if PokeAccess::Keys.key(sym)
        PokeAccess::TownMap.jump(scene, dir)
        break
      end
    end
  end
end
