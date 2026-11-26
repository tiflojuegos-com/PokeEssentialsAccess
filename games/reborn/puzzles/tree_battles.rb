# Rhodochrine Tree (map 886), Xerneas' and Yveltal's quest: on each of nine floors the ladder below sets Xerneas'
# strength (variable 661) and Yveltal's (662), and each wild Pokemon beaten takes its points off one side. Common event
# 68 checks after each fight: equal sides open the ladder up (660), one at 0 fails the floor (switch 1805).
module PokeAccess
  module RebornTree
    MAP = 886
    XERNEAS = 661
    YVELTAL = 662
    FAILED = 1805
    ROWS = 41
    FOES = {
      3 => [:x, 3, "Espeon"], 4 => [:y, 3, "Umbreon"], 5 => [:y, 3, "Umbreon"], 6 => [:x, 3, "Espeon"],
      7 => [:x, 3, "Espeon"], 16 => [:x, 3, "Espeon"], 17 => [:x, 2, "Chingling"], 18 => [:x, 2, "Chingling"],
      19 => [:y, 5, "Mightyena"], 37 => [:x, 7, "Togetic"], 38 => [:y, 3, "Umbreon"], 39 => [:y, 7, "Mismagius"],
      42 => [:x, 7, "Togetic"], 43 => [:x, 3, "Espeon"], 44 => [:x, 2, "Cleffa"], 45 => [:y, 7, "Mismagius"],
      46 => [:y, 7, "Mismagius"], 49 => [:y, 3, "Umbreon"], 50 => [:y, 3, "Umbreon"], 51 => [:y, 3, "Umbreon"],
      52 => [:x, 5, "Florges"], 53 => [:x, 2, "Flabebe"], 54 => [:x, 3, "Floette"], 64 => [:y, 13, "Zweilous"],
      65 => [:y, 13, "Zweilous"], 66 => [:x, 3, "Floette"], 67 => [:x, 3, "Floette"], 68 => [:x, 5, "Florges"],
      69 => [:x, 3, "Espeon"], 70 => [:x, 2, "Chingling"], 71 => [:x, 3, "Espeon"], 72 => [:x, 11, "Granbull"],
      73 => [:y, 13, "Zweilous"], 74 => [:y, 3, "Murkrow"], 75 => [:y, 5, "Houndour"], 76 => [:x, 2, "Spritzee"],
      77 => [:x, 11, "Kadabra"], 78 => [:x, 11, "Kadabra"], 79 => [:y, 5, "Houndour"], 80 => [:x, 11, "Granbull"],
      81 => [:x, 7, "Togetic"], 82 => [:y, 2, "Drifloon"], 83 => [:y, 17, "Mandibuzz"], 84 => [:x, 3, "Chimecho"],
      85 => [:x, 17, "Clefable"], 86 => [:y, 17, "Hydreigon"], 87 => [:y, 2, "Deino"], 88 => [:y, 2, "Deino"],
      89 => [:y, 2, "Deino"], 90 => [:y, 2, "Vullaby"], 91 => [:y, 2, "Poochyena"], 92 => [:y, 2, "Eevee"],
      93 => [:y, 2, "Misdreavus"]
    }

    # The floor the player stands on, from 1.
    def self.floor
      $game_player.y / ROWS + 1
    end

    # The foes of the player's floor still standing there, as [id, side, points].
    def self.standing
      FOES.map do |id, (side, pts, _n)|
        ev = $game_map.events[id]
        next nil unless ev && ev.y / ROWS + 1 == floor && !ev.character_name.to_s.empty?
        [id, side, pts]
      end.compact.sort
    end

    # Both strengths now, as [Xerneas, Yveltal].
    def self.sides
      [$game_variables[XERNEAS].to_i, $game_variables[YVELTAL].to_i]
    end

    @plans = {}

    # The fewest fights that even the sides from here, in order, with no check on the way failing; nil when none does.
    def self.plan
      x, y = sides
      return nil if x == y || $game_switches[FAILED]
      foes = standing
      key = [x, y, foes.map { |f| f[0] }]
      @plans[key] = search(x, y, foes) unless @plans.key?(key)
      @plans[key]
    end

    # Breadth first over the fights, each set of foes beaten queued once.
    def self.search(x, y, foes)
      seen = { 0 => true }
      queue = [[x, y, 0, []]]
      until queue.empty?
        cx, cy, mask, path = queue.shift
        foes.each_with_index do |foe, i|
          id, side, pts = foe
          bit = 1 << i
          next if mask & bit != 0
          nx = side == :x ? cx - pts : cx
          ny = side == :y ? cy - pts : cy
          return path + [id] if nx == ny
          beaten = mask | bit
          next if nx == 0 || ny == 0 || seen[beaten]
          seen[beaten] = true
          queue << [nx, ny, beaten, path + [id]]
        end
      end
      nil
    end

    # Drops the plans kept for the last map.
    def self.forget
      @plans = {}
    end

    # The next foe to beat with the assist, or nil.
    def self.next_id
      return nil unless PokeAccess::Puzzles.assist?
      pl = plan
      pl && pl.first
    end

    # A foe's name: its species, said as the next to beat with the assist.
    def self.label(ev)
      next_id == ev.id ? [:rbrd_tree_next, { :name => FOES[ev.id][2] }] : nil
    end

    # With the assist, the strengths and the fights that even them, or the way to start the floor over.
    def self.hint
      return :rbrd_tree_failed if $game_switches[FAILED] && standing.empty?
      pl = plan
      return nil unless pl
      x, y = sides
      [:rbrd_tree_hint, { :x => x, :y => y, :foes => pl.map { |id| FOES[id][2] }.join(", ") }]
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornTree.forget }

PokeAccess::Game.define("reborn") do
  tree = PokeAccess::RebornTree
  mechanic(:state, tree::MAP, :part => :battles) do
    auto
    name tree::FOES.keys, lambda { |ev| tree.label(ev) }, :assist => true
    hint lambda { tree.hint }
    info { nil }
    active { PokeAccess::Puzzles.assist? && !tree.hint.nil? }
  end
end
