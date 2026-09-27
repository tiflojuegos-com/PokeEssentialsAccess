module PokeAccess
  # Rejuvenation's region map (Rejuv/RegionMap.rb reworks PokemonRegionMapScene): the cursor is @selection over the
  # squares of $cache.town_map, whose [x, y] keys hold each place, its point of interest and its fly spot, and every
  # move rewrites the bottom bar; there is no pbGetMapLocation. Mode 1 is the fly map and mode 2, with a species, the
  # Pokedex nest page: its bar names the nest, its red squares are the nests and its cursor waits for C.
  module RejuvMap
    # Whether the scene is this rework: a @selection cursor over the town map in $cache.
    def self.handles?(s)
      PokeAccess.ivar(s, :@selection).is_a?(Array) && PokeAccess.ivar(s, :@mapdata).is_a?(Hash)
    end

    # The mode the scene was opened in: 0 the map, 1 to fly, 2 the nest page.
    def self.mode(s)
      PokeAccess.ivar(s, :@access_rj_mode).to_i
    end

    # The cursor's square, or nil while the cursor is hidden.
    def self.cursor(s)
      cur = PokeAccess.sprite(s, "cursor")
      return nil if cur && !cur.visible
      sel = PokeAccess.ivar(s, :@selection)
      sel ? [sel[0], sel[1]] : nil
    end

    # The squares of the regions on show.
    def self.points(s)
      regions = Array(PokeAccess.ivar(s, :@region))
      rows = PokeAccess.ivar(s, :@mapdata).select { |k, v| k.is_a?(Array) && regions.include?((v.region rescue nil)) }
      rows.map { |k, _v| [k[0], k[1]] }
    rescue StandardError
      []
    end

    # Whether the square has a fly spot (getFlySpot) on a visited map, as the fly map's icons mark it.
    def self.fly_here?(s, xy)
      spot = (s.getFlySpot(xy) rescue nil)
      spot ? PokeAccess::TownMap.visited?(spot) : false
    end

    # The squares the player can fly to.
    def self.flyable(s)
      points(s).select { |xy| fly_here?(s, xy) }
    end

    # The nest squares the page paints red, from its point sprites (each eight pixels into its square).
    def self.nests(s)
      k = s.class
      (0...PokeAccess.ivar(s, :@numpoints).to_i).map { |i| PokeAccess.sprite(s, "point#{i}") }.compact.map do |sp|
        [(sp.x - 8) / k::SQUAREWIDTH, (sp.y - 8) / k::SQUAREHEIGHT]
      end
    rescue StandardError
      []
    end

    # A window coordinate kept between lo and hi by scrolling the viewport along axis by the excess, in squares.
    def self.scroll(vp, axis, v, lo, hi, size)
      over = v > hi ? v - hi : (v < lo ? v - lo : 0)
      vp.send("#{axis}=", vp.send(axis) + over * size) if vp && over != 0
      v - over
    end

    # Puts the cursor on (x, y) as the arrows would, moving @selection in place as the scene does: the view scrolls to
    # keep it in its window, the sprite moves and the bottom bar is rewritten, unsaid, for the next frame's reader.
    def self.move(s, x, y)
      k = s.class
      sel = PokeAccess.ivar(s, :@selection)
      vp = PokeAccess.ivar(s, :@viewport)
      mx = scroll(vp, :ox, PokeAccess.ivar(s, :@mapX).to_i + x - sel[0], k::LEFT, k::SCREENRIGHT, k::SQUAREWIDTH)
      my = scroll(vp, :oy, PokeAccess.ivar(s, :@mapY).to_i + y - sel[1], k::TOP, k::SCREENBOTTOM, k::SQUAREHEIGHT)
      s.instance_variable_set(:@mapX, mx)
      s.instance_variable_set(:@mapY, my)
      sel[0] = x
      sel[1] = y
      cur = PokeAccess.sprite(s, "cursor")
      if cur
        cur.x = k::SQUAREWIDTH * x
        cur.y = k::SQUAREHEIGHT * y
      end
      rewrite_bar(s)
    end

    # Writes the bottom bar for the cursor's square as the scene's own move does, with the bar's readers held.
    def self.rewrite_bar(s)
      bar = PokeAccess.sprite(s, "mapbottom")
      return unless bar
      PokeAccess::RegionMap.building do
        bar.maplocation = s.getMapName
        unless mode(s) == 2
          bar.mapdetails = s.getPOI
          bar.mapname = s.getRegionName
        end
      end
    end

    # The line for a square: its place, or its coordinates where it has none; its point of interest, save on the nest
    # page; fly where the fly map marks it; the nest mark on the nest page; and whether the player is there.
    def self.square_text(s, xy)
      place = PokeAccess.clean(s.getMapName.to_s)
      parts = [place.empty? ? PokeAccess::I18n.t(:brm_square, :x => xy[0], :y => xy[1]) : place]
      unless mode(s) == 2
        poi = PokeAccess.clean(s.getPOI.to_s)
        parts.push(poi) unless poi.empty?
      end
      parts.push(PokeAccess::I18n.t(:brm_fly)) if mode(s) == 1 && fly_here?(s, xy)
      parts.push(PokeAccess::I18n.t(:rj_map_nest)) if mode(s) == 2 && nests(s).include?(xy)
      parts.push(PokeAccess::I18n.t(:rmap_you)) if PokeAccess.ivar(s, :@access_rj_you) == xy
      parts.join(", ")
    end

    # The region's name as the bar paints it, marked on the bar's region slot so its own reader keeps quiet; "" on the
    # nest page, whose bar has none, or when it is the one last said.
    def self.region_news(s)
      return "" if mode(s) == 2
      region = PokeAccess.clean(s.getRegionName.to_s)
      (region.empty? || !PokeAccess::Cursor.changed?(nil, :regionname, region)) ? "" : region
    end

    # Says the square when the cursor lands on a new one or comes back into view, the region first where it changed,
    # and marks the bar's place slot so the bar's own reader keeps quiet; silent while a build or a bar write runs.
    def self.follow(s)
      return if PokeAccess::RegionMap.building? || !handles?(s)
      xy = cursor(s)
      if xy.nil?
        sel = PokeAccess.ivar(s, :@selection)
        PokeAccess::Cursor.store(s, :rj_map, [sel ? [sel[0], sel[1]] : nil, false])
        return
      end
      return unless PokeAccess::Cursor.changed?(s, :rj_map, [xy, true])
      line = PokeAccess.sentences([region_news(s), square_text(s, xy)])
      PokeAccess::Cursor.changed?(nil, :regionmap, PokeAccess.clean(s.getMapName.to_s))
      PokeAccess.speak(line, true)
    rescue StandardError => e
      PokeAccess.log_once("rj_map", e)
    end

    # The nest page as it opens: the bar's nest, then its "No Known Nests" where it paints one, and the places the
    # species is found in, from the encounters the page lists.
    def self.nest_text(s)
      bar = PokeAccess.sprite(s, "mapbottom")
      title = PokeAccess.clean(PokeAccess.ivar(bar, :@mapdetails).to_s)
      alt = PokeAccess.clean(PokeAccess.ivar(bar, :@alttext).to_s)
      places = Array(PokeAccess.ivar(s, :@encounters)).map { |e| PokeAccess.clean(e[1].to_s) }.reject { |n| n.empty? }.uniq
      list = places.empty? ? nil : PokeAccess::I18n.t(:pdx_places, :list => places.join(", "))
      PokeAccess.sentences([title, alt, list])
    end

    # The opening line: the nest page's nest, else the region and the square the cursor starts on, both marked so
    # the frame reader and the bar do not say them again.
    def self.opening(s)
      return nest_text(s) if mode(s) == 2
      region = region_news(s)
      xy = cursor(s)
      return region if xy.nil?
      PokeAccess::Cursor.store(s, :rj_map, [xy, true])
      PokeAccess::Cursor.changed?(nil, :regionmap, PokeAccess.clean(s.getMapName.to_s))
      PokeAccess.sentences([region, square_text(s, xy)])
    end

    # Runs the scene's build with the bottom bar unsaid (its first writes name the player's place, which the nest page
    # then blanks), notes the player's square where the map draws the player's head, and says the opening, queued.
    # param args pbStartScene's (aseditor, mode, dummymon, showcursor)
    def self.build(s, args)
      s.instance_variable_set(:@access_rj_mode, args[1].to_i)
      ret = nil
      PokeAccess::RegionMap.building { ret = yield }
      if handles?(s)
        sel = PokeAccess.ivar(s, :@selection)
        s.instance_variable_set(:@access_rj_you, [sel[0], sel[1]]) if PokeAccess.sprite(s, "player")
        PokeAccess.speak(opening(s), false)
      end
      ret
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  around("PokemonRegionMapScene", :pbStartScene, :optional => true) do |s, nxt, args|
    PokeAccess::RejuvMap.build(s, args) { nxt.call }
  end

  before("PokemonRegionMapScene", :pbUpdate, :optional => true) { |s, _a| PokeAccess::RejuvMap.follow(s) }

  around("PokemonRegionMapScene", :pbChangeMapFocus, :optional => true) do |_s, nxt, _a|
    PokeAccess::RegionMap.building { nxt.call }
  end

  after("PokemonRegionMapScene", :endNestScene, :optional => true) do |s, _r, _a|
    PokeAccess::RegionMap.forget(s)
    PokeAccess::TownMap.closed(s)
  end

  override("PokeAccess::UIV21", :region_name) do |_mod, original, _args|
    PokeAccess::RegionMap.building? ? nil : original.call
  end
end

PokeAccess::TownMap.register(
  :rejuvenation,
  lambda { |s| PokeAccess::RejuvMap.handles?(s) },
  lambda { |s| PokeAccess::RejuvMap.cursor(s) },
  lambda { |s, x, y| PokeAccess::RejuvMap.move(s, x, y) },
  lambda { |s| PokeAccess::RejuvMap.points(s) },
  lambda { |s| PokeAccess::RejuvMap.flyable(s) }
)
