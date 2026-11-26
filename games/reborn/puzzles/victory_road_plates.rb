# Victory Road's plates in the first atrium (map 784, 812 once the pillar has blown) and the second (787, 813): each
# waits for one boulder whose page sets a gate's switch. A row is [boulder event, plate tile, gate switch]; the plate at
# (48,51) goes off as its boulder leaves it. With the assist, the nearest due boulder is tracked into its plate.
module PokeAccess
  module RebornVrPlates
    ATRIUM1 = [[68, [44, 37], 1101], [71, [57, 56], 1108], [80, [55, 42], 1118], [76, [71, 32], 1119],
               [77, [71, 28], 1119], [73, [76, 57], 1120], [75, [103, 54], 1121], [135, [106, 23], 1124]]
    ATRIUM2 = [[65, [48, 51], 1155], [74, [48, 65], 1156]]
    MAPS = { 784 => ATRIUM1, 812 => ATRIUM1, 787 => ATRIUM2, 813 => ATRIUM2 }

    # True while the plate still waits: its gate shut and its boulder off it.
    def self.due?(row)
      return false if $game_switches[row[2]]
      ev = $game_map.events[row[0]]
      !ev.nil? && [ev.x, ev.y] != row[1]
    end

    NEAR = 20

    # Tiles from the player to the row's boulder.
    def self.distance(row)
      ev = $game_map.events[row[0]]
      (ev.x - $game_player.x).abs + (ev.y - $game_player.y).abs
    end

    # With the assist, the due row being tracked: kept while due and within NEAR tiles, else the one whose boulder lies
    # nearest the player; nil without the assist or with none due.
    def self.current
      return nil unless PokeAccess::Puzzles.assist?
      rows = MAPS[$game_map.map_id] || []
      kept = @current && rows.any? { |row| row.equal?(@current) } && due?(@current) && distance(@current) <= NEAR
      return @current if kept
      @current = rows.select { |row| due?(row) }.min_by { |row| distance(row) }
    end

    # Drops the tracked row, on a new map.
    def self.forget; @current = nil; end
  end
end

PokeAccess::Game.define("reborn") do
  plates = PokeAccess::RebornVrPlates
  [[[784, 812], plates::ATRIUM1], [[787, 813], plates::ATRIUM2]].each do |maps, rows|
    mechanic(:state, maps, :part => :plates) do
      auto
      rows.each do |row|
        x, y = row[1]
        spot :at => row[1], :label => :rbc_vr_plate, :onto => true, :when => lambda { plates.due?(row) }
        phase(lambda { plates.current.equal?(row) }, :quiet => true, :hint => :rbc_vr_plates_hint,
              :track => { :event => row[0], :label => :rbc_vr_plate_boulder, :goal => [x, y, x, y],
                          :goal_label => :rbc_vr_plate_goal })
      end
      solved { rows.all? { |row| $game_switches[row[2]] } }
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornVrPlates.forget }
