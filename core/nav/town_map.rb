module PokeAccess
  # Moving the region map's cursor, the ONE thing the three region-map implementations do not share. Reading
  # is uniform (pbGetMapLocation / pbGetMapDetails / pbGetHealingSpot are the same three names in all
  # thirteen games, see nav/region_map), so this exists only for the fly-jump.
  #
  # Dispatch is by SHAPE, never by class name or engine version, because the names lie: Arcky's Region Map
  # and the v21+ UI rework BOTH define PokemonRegionMap_Scene, with the cursor in different ivars. A profile
  # can register its own provider and it WINS, since providers are searched newest first and profiles load
  # after the core -- fangames rewrite this screen freely, sprites, zoom and custom point tables included.
  module TownMap
    # provider: [name, handles?(scene), cursor(scene) -> [x,y], move(scene,x,y), points(scene) -> [[x,y]..],
    # flyable(scene) -> [[x,y]..] or nil]
    def self.providers; @providers ||= []; end

    # Registers a cursor provider. Last registered wins, so a profile overrides the built-ins.
    # param flyable only for a screen that KNOWS its own flyable set; the generic rule below derives it from
    #   pbGetHealingSpot plus visitedMaps, which is what the standard screens draw their icon from, and a
    #   screen with a fly-anywhere mode of its own draws more places than that rule allows
    def self.register(name, handles, cursor, move, points, flyable = nil)
      providers.push([name, handles, cursor, move, points, flyable])
    end

    # The provider that fits this scene, or nil when none does (the feature then simply does not exist for
    # that game -- never a half-working jump).
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

    # Every point on the map as [x, y] pairs -- the CANDIDATES, not the flyable ones: whether a point can
    # be flown to is the game's answer (pbGetHealingSpot), never ours to infer.
    def self.points(scene)
      p = provider_for(scene)
      return [] unless p
      (p[4].call(scene) rescue []) || []
    end

    # The subset of points the screen actually MARKS as flyable, as [x, y]. Two rules, both the game's own:
    # pbGetHealingSpot says whether the square has a destination at all, and visitedMaps says whether the
    # player has been there. The screen draws its fly icon under both and refuses the jump without the
    # second, so asking only the first offered towns that pressing action will not go to.
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

    # The healing spot for a map square, asked the way THIS copy declares the method: most take (x, y) and
    # one takes the map data first. A fixed arity turned every answer into nil through the rescue, and the
    # jump then reported "nowhere to fly" over a map full of towns.
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

    # Whether the destination's map has been visited, which is the flyable rule the screen adds on top.
    # A game with no such record answers yes, so a missing accessor cannot empty the list.
    def self.visited?(spot)
      id = spot.is_a?(Array) ? spot[0] : nil
      return true if id.nil?
      v = ($PokemonGlobal.visitedMaps rescue nil)
      return true if v.nil?
      v[id] ? true : false
    rescue StandardError
      true
    end

    # Whether the jump is offered at all. A profile turns it off when its game already has something
    # better: Arcky's Region Map ships a Quick Fly that lists the visited places BY NAME, which
    # beats jumping blind in a direction, so duplicating it there would make the screen worse.
    def self.jump_enabled; @jump_enabled = true if @jump_enabled.nil?; @jump_enabled; end
    def self.jump_enabled=(v); @jump_enabled = v; end

    # The map scene currently on screen, or nil. Its own loop blocks the map driver, so this is the only
    # way the per-frame poll knows the screen is up -- and clearing it is what keeps J/K/L/I doing the
    # locator's job everywhere else.
    def self.open_scene; @open; end

    def self.opened(scene)
      @open = scene
      @fly_cache = nil
    end

    def self.closed(_scene)
      @open = nil
      @fly_cache = nil
    end

    # The flyable points of the open scene, computed once per opening: pbGetHealingSpot walks the point
    # table on every call, and a keypress must not pay for that repeatedly.
    def self.fly_cache(scene)
      @fly_cache ||= fly_points(scene)
    end

    # Jumps to the nearest flyable point in a direction. Returns true when the cursor moved.
    #
    # It deliberately does NOT announce the destination: the scene's own loop calls pbGetMapLocation with
    # the new coordinates on the very next frame, and the existing reader speaks it there. One announcer.
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

    # The nearest flyable point strictly in one direction from (x, y), or nil.
    #
    # "Nearest in that direction" and not "nearest overall": the player is navigating a map they cannot
    # see, and a jump that lands somewhere behind them destroys the mental picture they are building. Ties
    # break by the smaller sideways drift, so pressing right twice walks a row instead of zig-zagging.
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

# gen-6 vanilla and Arcky's plugin: the cursor is @mapX/@mapY and the points are the raw @map[2] rows.
#
# Moving it drags the drawn cursor along too. The scene recomputes the NAME from the ivars every frame but
# only repositions the sprite on its own animated path, so setting the ivars alone would leave the icon
# behind. The formula is the one the scene runs two lines before its loop; without the sprite or the
# constants it just moves the ivars, which still works.
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

# The v21+ UI rework: snake_case ivars and the point list behind @map.point. Here the scene exposes its own
# point-to-screen helpers, so the sprite is placed by ASKING it instead of copying arithmetic.
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
  lambda { |s| m = PokeAccess.ivar(s, :@map); (m && m.point ? m.point : []).map { |p| [p[0], p[1]] } }
)

# J K L I while the map is up. They are the locator's keys, and the locator's own driver hangs off
# Game_Player#update, which does NOT run inside the map's blocking loop -- so there is nothing to arbitrate:
# the keys are simply free here. Outside the map open_scene is nil and this costs one nil check per frame.
PokeAccess::TownMap::DIRS = { :prev => :left, :next => :right, :route => :up, :where => :down }

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
