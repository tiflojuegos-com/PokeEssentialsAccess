module PokeAccess
  # Armonia's region map pans two side-by-side maps under a cursor in window squares (a place's coordinates are the
  # cursor's shifted by its map's pan), so its fly jump works in window squares over the points the window shows.
  module ArmoniaMap
    # [window x, window y, map, point] for every point of both maps inside the window.
    def self.placed(s)
      k = s.class
      out = []
      [[:@map1, :@map1TransformX, :@map1TransformY, -1], [:@map2, :@map2TransformX, :@map2TransformY, 1]].each do |miv, tx, ty, sign|
        m = PokeAccess.ivar(s, miv)
        next unless m.is_a?(Array) && m[2].is_a?(Array)
        m[2].each do |pt|
          x = pt[0] + sign * PokeAccess.ivar(s, tx).to_i
          y = pt[1] + sign * PokeAccess.ivar(s, ty).to_i
          out.push([x, y, m, pt]) if x >= k::LEFT && x <= k::RIGHT && y >= k::TOP && y <= k::BOTTOM
        end
      end
      out
    rescue StandardError
      []
    end

    # The window squares the screen marks for flying: a place with a healing spot the player has visited.
    def self.flyable(s)
      placed(s).select do |_x, _y, m, pt|
        spot = (s.pbGetHealingSpot(m, pt[0], pt[1]) rescue nil)
        spot && PokeAccess::TownMap.visited?(spot)
      end.map { |x, y, _m, _pt| [x, y] }
    end

    # Keeps the map the player's head is drawn on, once pbStartScene has built the screen; nil without a head.
    def self.note_head(s)
      s.instance_variable_set(:@access_head_map, PokeAccess.sprite(s, "player") ? PokeAccess.ivar(s, :@map) : nil)
    rescue StandardError
      nil
    end

    # The core's player mark, kept only on the map the head is drawn on: both maps number their squares from 0, so a
    # square of the other map can share the player's coordinates.
    # param original the core's own answer, as a callable
    def self.player_square?(s, original)
      return false unless original.call
      head = PokeAccess.ivar(s, :@access_head_map)
      head.nil? || head.equal?(PokeAccess.ivar(s, :@map))
    end

    # Puts the cursor on a window square, on the map the place there belongs to, as the screen would.
    def self.move(s, x, y)
      hit = placed(s).find { |px, py, _m, _pt| px == x && py == y }
      if hit
        s.instance_variable_set(:@map, hit[2])
        s.instance_variable_set(:@mapindex, hit[2].equal?(PokeAccess.ivar(s, :@map1)) ? 0 : 1)
      end
      s.instance_variable_set(:@mapX, x)
      s.instance_variable_set(:@mapY, y)
      cur = PokeAccess.sprite(s, "cursor")
      k = s.class
      return unless cur
      cur.x = -k::SQUAREWIDTH / 2 + (x * k::SQUAREWIDTH) + 16
      cur.y = -k::SQUAREHEIGHT / 2 + (y * k::SQUAREHEIGHT) + 32
    end
  end
end

# pbStartScene asks pbGetMapLocation with the unshifted window square, wrong on the second map, so the build is
# left unsaid and the loop's first ask says the place; the map the head sits on is kept for the player's mark.
PokeAccess::Game.define("armonia") do
  around("PokemonRegionMapScene", :pbStartScene, :optional => true) do |scene, nxt, _a|
    r = PokeAccess::RegionMap.building { nxt.call }
    PokeAccess::ArmoniaMap.note_head(scene)
    r
  end
  override(PokeAccess::RegionMap, :player_square?) do |_mod, original, args|
    PokeAccess::ArmoniaMap.player_square?(args[0], original)
  end
end

PokeAccess::TownMap.register(
  :armonia,
  lambda { |s| s.respond_to?(:transformX) && !PokeAccess.ivar(s, :@map1).nil? },
  lambda { |s| [PokeAccess.ivar(s, :@mapX), PokeAccess.ivar(s, :@mapY)] },
  lambda { |s, x, y| PokeAccess::ArmoniaMap.move(s, x, y) },
  lambda { |s| PokeAccess::ArmoniaMap.placed(s).map { |x, y, _m, _pt| [x, y] } },
  lambda { |s| PokeAccess::ArmoniaMap.flyable(s) }
)
