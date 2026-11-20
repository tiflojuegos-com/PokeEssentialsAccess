# Edas' Carcitoma, past the crystal hall of Monte Azur: two mazes of rooms whose four edges each lead to another room, and a
# corridor of hidden buttons. In the sea of the lost (maps 99 to 105 and 107) and the forest of the absurd (maps 106, 113 and
# 115 to 121) the edges are named by their side, the forest's also by the path painted there (tileset 33: grey cobbles of
# Camino Corvus, STONE, or brown earth of Dirt_Forest_Path_AT), and the assist lists the one that leads on; the forest's goal
# (map 121) asks for its value in writing. In the corridor of the hasty (map 108) four hidden buttons are pressed in turn,
# each followed by the pass to the north (event 7), which moves the shelves' rhyme on (switches 163 to 165) and sends the
# player back south; leaving by the south (event 4) before the end starts it over.
module PokeAccess
  module EdasCarcitomaMazes
    WAYS = { 99 => [[4, 5, 6, 7], :dir_s], 102 => [[5, 6, 7, 8], :dir_o], 104 => [[5, 6, 7, 8], :dir_n],
             105 => [[6, 7, 8, 9], :dir_s], 100 => [[5, 6, 7, 8], :dir_n], 101 => [[1, 6, 7, 8], :dir_n],
             103 => [[17, 18, 19, 20], :dir_n], 113 => [[8, 9, 10], :dir_e], 117 => [[10, 11, 12, 13], :dir_n],
             119 => [[10, 11], :dir_e], 120 => [[9, 10, 11, 12], :dir_n], 116 => [[5, 6], :dir_e],
             106 => [[10, 11, 12], :dir_e], 118 => [[9, 10, 11, 12], :dir_n], 115 => [[5, 6, 7], :dir_n] }
    STONE = { 106 => [:dir_o], 113 => [:dir_n, :dir_s, :dir_e], 116 => [:dir_n, :dir_o, :dir_e],
              118 => [:dir_n, :dir_s, :dir_e], 119 => [:dir_e], 120 => [:dir_n, :dir_s, :dir_e] }
    FOREST = [106, 113, 115, 116, 117, 118, 119, 120, 121]
    GOAL = 121
    GOAL_SIGNS = [7, 8]
    GOAL_VALUE = "23"
    CORRIDOR = 108
    STAGE = 49
    RHYMES = [163, 164, 165]
    PASS = 7
    EXIT = 4
    BEATEN = 160
    BUTTONS = [23, 8, 18, [11, 12]]
    OBJECTS = [[[23], :edas_corr_slabs], [[8, 6], :edas_corr_crack], [[9, 10, 11, 12, 13, 14, 15, 16], :edas_corr_fountain],
               [[18, 19, 20, 21, 22], :edas_corr_pillar]]

    # The side of the room an edge exit stands on, as its name, in the forest with the path of that side; nil for any
    # other event.
    def self.side_name(ev)
      return nil unless PokeAccess::Locator.transfer_event?(ev)
      dir = if ev.y == 0 then :dir_n
            elsif ev.y == $game_map.height - 1 then :dir_s
            elsif ev.x == 0 then :dir_o
            elsif ev.x == $game_map.width - 1 then :dir_e
            end
      dir ? PokeAccess::I18n.t(exit_key(dir), :dir => PokeAccess::I18n.t(dir)) : nil
    end

    # The key an exit on side dir is named with: by its path in the forest, else by its side alone.
    def self.exit_key(dir)
      map = $game_map.map_id
      return :edas_maze_exit unless FOREST.include?(map)
      (STONE[map] || []).include?(dir) ? :edas_forest_exit_stone : :edas_forest_exit_dirt
    end

    # Whether the corridor is behind the player: what waits past it (map 126) beaten, switch 160.
    def self.beaten?
      $game_switches[BEATEN] ? true : false
    end

    # The corridor's stage: the buttons pressed, 0 to 4.
    def self.stage
      [[$game_variables[STAGE].to_i, 0].max, BUTTONS.length].min
    end

    # Whether the pass to the north has taken in the stage's button: the next rhyme on, or the pass's own switch at the end.
    def self.crossed?
      s = stage
      return false if s == 0
      return $game_self_switches[[CORRIDOR, PASS, "A"]] ? true : false if s == BUTTONS.length
      $game_switches[RHYMES[s - 1]] ? true : false
    end

    # What the corridor wants next: the pass after a button, else the next button, and the pass once all are in.
    def self.next_piece
      return PASS if stage == BUTTONS.length || (stage > 0 && !crossed?)
      BUTTONS[stage]
    end

    # The assist's line: the piece the corridor wants next, by name.
    def self.corridor_hint
      piece = next_piece
      return PokeAccess::I18n.t(:edas_corr_hint_pass) if piece == PASS
      label = OBJECTS.find { |ids, _label| ids.include?([piece].flatten[0]) }[1]
      PokeAccess::I18n.t(:edas_next, :what => PokeAccess::I18n.t(label))
    end
  end
end

PokeAccess::Game.define("edas") do
  mazes = PokeAccess::EdasCarcitomaMazes
  mazes::WAYS.each do |map, (exits, dir)|
    mechanic(:state, map) do
      auto
      name(/./, lambda { |ev| mazes.side_name(ev) }, :when => false)
      active { PokeAccess::Puzzles.assist? }
      phase lambda { true }, :hidden => right_way(*exits),
                             :hint => lambda { PokeAccess::I18n.t(:edas_maze_hint, :dir => PokeAccess::I18n.t(dir)) }
    end
  end

  mechanic(:state, mazes::GOAL) do
    auto
    name(/./, lambda { |ev| mazes.side_name(ev) }, :when => false)
    answer mazes::GOAL_SIGNS, mazes::GOAL_VALUE
  end

  mechanic(:state, mazes::CORRIDOR) do
    auto
    mazes::OBJECTS.each do |ids, label|
      name ids, label, :grouped => label == :edas_corr_fountain, :when => lambda { |_ev| !mazes.beaten? }
    end
    avoid mazes::EXIT
    sent_back :edas_corr_back, :to => [9, 12], :events => [mazes::PASS]
    arrival_hint :edas_corr_rule
    solved { mazes.beaten? }
    active { PokeAccess::Puzzles.assist? }
    (0..mazes::BUTTONS.length).each do |s|
      if s > 0
        phase lambda { mazes.stage == s && !mazes.crossed? }, :hint => lambda { mazes.corridor_hint },
                                                              :hidden => right_way(mazes::PASS)
      end
      piece = mazes::BUTTONS[s] || mazes::PASS
      phase lambda { mazes.stage == s && (s == 0 || mazes.crossed?) }, :hint => lambda { mazes.corridor_hint },
                                                                       :hidden => right_way(*[piece].flatten)
    end
  end
end
