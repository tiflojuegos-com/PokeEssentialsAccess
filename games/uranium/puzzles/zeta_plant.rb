# Nuclear Plant Zeta (maps 189 to 192): variable 126 counts the power coming back. The south levers (events 14, 16 and 15,
# green, red and blue) must be pulled in that order and then the circuit breaker (25); a wrong order discharges the team
# and puts the levers back. Then the east (map 191, event 4, adds 2) and west (map 192, event 19, adds 1) levers take it to 7,
# which with a POWERCELL opens the north door (map 190, event 6). The story's end sets it to 8 and 9 (map 193).
module PokeAccess
  # The outer yard (map 190): whether the central boulders still shut the way from the south door (24, 36) to the tile in
  # front of the north door (24, 14).
  module UraniumZetaPatio
    # The ids of the central boulders.
    def self.boulders
      [4, 5, 8, 9, 10, 11, 12, 13, 14, 15, 16]
    end

    # The pushes that open the way, in order, as the boulder's square, the direction (2, 4, 6 or 8) and the times.
    def self.pushes
      [[23, 22, 8, 1], [25, 22, 8, 1], [24, 22, 4, 1], [23, 20, 4, 1], [24, 19, 6, 1], [24, 18, 8, 2], [25, 17, 6, 1]]
    end

    # The hint: each push in words, then the rest of the line.
    def self.hint
      words = { 4 => :ura_po_dir_left, 6 => :ura_po_dir_right, 8 => :ura_po_dir_up }
      list = pushes.map do |x, y, dir, times|
        PokeAccess::I18n.t(times > 1 ? :ura_po_zeta_push_twice : :ura_po_zeta_push,
                           :x => x, :y => y, :dir => PokeAccess::I18n.t(words[dir]))
      end
      [:ura_po_zeta_patio_hint, { :list => list.join("; ") }]
    end

    # Whether the way is open, remembered while the boulders do not move.
    def self.open?
      stones = boulders.map { |id| ev = $game_map.events[id]; ev ? [ev.x, ev.y] : nil }.compact
      return @open if @stones == stones && !@open.nil?
      @stones = stones
      @open = reach?(stones)
    end

    # Flood fill from the south door over the tiles the game lets the player walk, boulders apart.
    def self.reach?(stones)
      seen = { [24, 36] => true }
      queue = [[24, 36]]
      until queue.empty?
        x, y = queue.shift
        return true if [x, y] == [24, 14]
        [[2, 0, 1], [4, -1, 0], [6, 1, 0], [8, 0, -1]].each do |dir, dx, dy|
          nxt = [x + dx, y + dy]
          next if seen[nxt] || stones.include?(nxt) || nxt[0] < 0 || nxt[1] < 0 || nxt[0] >= 50 || nxt[1] >= 50
          next unless $game_map.passable?(x, y, dir) && $game_map.passable?(nxt[0], nxt[1], 10 - dir)
          seen[nxt] = true
          queue << nxt
        end
      end
      false
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 189, :part => :levers) do
    auto
    name 14, :ura_pz_zeta_lever_green
    name 16, :ura_pz_zeta_lever_red
    name 15, :ura_pz_zeta_lever_blue
    name 25, :ura_pz_zeta_breaker
    arrival_hint :ura_pz_zeta_rule
    solved(nil) { $game_variables[126].to_i >= 4 }
  end

  mechanic(:state, 191, :part => :levers) do
    auto
    name 4, :ura_pz_zeta_east
  end

  mechanic(:state, 192, :part => :levers) do
    auto
    name 19, :ura_pz_zeta_west
  end

  mechanic(:state, 190, :part => :levers) do
    auto
    name 6, :ura_pz_zeta_door
  end

  mechanic(:state, [189, 190, 191, 192], :part => :power) do
    auto
    phase lambda { $game_variables[126].to_i < 4 }, :quiet => true, :hint => :ura_pz_zeta_hint_south
    phase lambda { $game_variables[126].to_i == 4 }, :quiet => true, :hint => :ura_pz_zeta_hint_sectors
    phase lambda { $game_variables[126].to_i == 5 }, :quiet => true, :hint => :ura_pz_zeta_hint_east
    phase lambda { $game_variables[126].to_i == 6 }, :quiet => true, :hint => :ura_pz_zeta_hint_west
    phase lambda { $game_variables[126].to_i == 7 }, :quiet => true, :hint => :ura_pz_zeta_hint_door
  end

  mechanic(:state, 192, :part => :boulders) do
    auto
    arrival_hint :ura_po_zeta_west_rule, :once => true
    phase lambda { !$game_self_switches[[192, 13, "A"]] }, :quiet => true, :hint => :ura_po_zeta_west_hint
  end

  mechanic(:state, 190, :part => :boulders) do
    auto
    arrival_hint :ura_po_zeta_patio_rule, :once => true
    solved(nil, :quiet => true) { PokeAccess::UraniumZetaPatio.open? }
    phase lambda { !PokeAccess::UraniumZetaPatio.open? }, :quiet => true, :hint => lambda { PokeAccess::UraniumZetaPatio.hint }
  end
end
