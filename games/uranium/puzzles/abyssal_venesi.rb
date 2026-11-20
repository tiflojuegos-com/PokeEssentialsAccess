# Abyssal Venesi (map 71), the dream maze: touching a Master rolls the good branch of the stage into variable 35 (0 to 2)
# and the stage number sits in variable 30; going through the good door moves on and puts variable 35 at 4, any other
# door sends the player back to the first Master. Each Master's three branches end at the events of its stage's row.
module PokeAccess
  # The maze's stage and rolled branch as the assisted hints read them.
  module UraniumAbyss

    # Each Master as its stage, its event and the end events of its branches 0, 1 and 2.
    def self.stages
      [[0, 27, [24, 25, 28]], [1, 38, [37, 43, 42]], [1, 66, [67, 67, 67]],
       [2, 44, [53, 54, 45]], [2, 77, [78, 80, 74]], [3, 57, [58, 60, 59]]]
    end

    # The maze's stage, variable 30.
    def self.stage
      $game_variables[30].to_i
    end

    # Whether a Master has rolled the branch of the stage the maze is at.
    def self.rolled?
      (0..3).include?(stage) && (0..2).include?($game_variables[35].to_i)
    end

    # The Master of the stage nearest to the player, within reach of the player, as a row of STAGES.
    def self.master
      rows = stages.select { |row| row[0] == stage && $game_map.events[row[1]] }
      near = rows.map { |row| [distance(row[1]), row] }.select { |d, _row| d <= 30 }
      near.empty? ? nil : near.sort_by { |d, _row| d }.first[1]
    end

    # Walking distance as the crow flies from the player to an event.
    def self.distance(id)
      ev = $game_map.events[id]
      (ev.x - $game_player.x).abs + (ev.y - $game_player.y).abs
    end

    # The event whose spot lies on the good branch, or nil.
    def self.target
      return nil unless rolled?
      row = master
      row ? row[2][$game_variables[35].to_i] : nil
    end

    # Whether the event is the end of the good branch.
    def self.way?(id)
      target == id
    end

    # The good branch's hint with the spot where the game makes its guide flash.
    def self.hint
      ev = $game_map.events[target]
      [:ura_po_abyss_hint, { :x => ev.x, :y => ev.y }]
    end

    # Whether a Master has still to roll the branch of the stage.
    def self.pending?
      (0..3).include?(stage) && !(0..2).include?($game_variables[35].to_i) && !master.nil?
    end
  end
end

PokeAccess::Game.define("uranium") do
  maze = PokeAccess::UraniumAbyss

  mechanic(:state, 71) do
    auto
    arrival_hint :ura_po_abyss_rule, :once => true
    name [27, 38, 44, 57, 66, 77], :ura_po_abyss_master
    [24, 25, 28, 37, 43, 42, 53, 54, 45, 58, 60, 59, 78, 80, 74, 67].each do |id|
      spot :event => id, :label => :ura_po_abyss_way, :assist => true, :when => lambda { maze.way?(id) }
    end
    phase lambda { maze.target }, :quiet => true, :hint => lambda { maze.hint }
    phase lambda { maze.pending? }, :quiet => true, :hint => :ura_po_abyss_touch
  end
end
