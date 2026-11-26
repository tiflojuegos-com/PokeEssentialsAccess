# The School of Nightmares on the Platinum route (map 160): four terminals with no sprite (events 3, 8, 11, 17) each
# open a room of crates; every arrow press slides all the crates at once, each stopping at an obstacle, until the moving
# crate (event 12) rests on its delivery tile (switches 1313, 1316, 1314, 1315). The four set variable 685 to 27.
module PokeAccess
  module RejuvSchoolOfNightmares
    # Terminal event => [its switch, the player's tile in its room, the delivery tile, the shortest presses].
    TERMINALS = {
      3 => [1313, [10, 45], [14, 47], %w[up right up right up left down right down left down right]],
      8 => [1316, [42, 45], [40, 43], %w[up right up left up left down right up left down]],
      11 => [1314, [26, 45], [22, 43], %w[down left up left up right up right up left down left]],
      17 => [1315, [57, 45], [61, 45], %w[down right up right down left down right up left down right down right up right
                                          down right]]
    }

    # A terminal's name, delivered or not by its switch.
    def self.terminal(ev)
      t = TERMINALS[ev.id]
      t && $game_switches[t[0]] ? :rjd_sn_terminal_done : :rjd_sn_terminal
    end

    # With the assist, a room's presses from the start, said in the language's words for the directions.
    def self.moves(id)
      words = TERMINALS[id][3].map { |d| PokeAccess::I18n.t("dir_#{d}".to_sym) }
      [:rjd_sn_moves, { :moves => words.join(", ") }]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  school = PokeAccess::RejuvSchoolOfNightmares
  mechanic(:state, 160, :part => :terminals) do
    auto
    name school::TERMINALS.keys, lambda { |ev| school.terminal(ev) }
    count :rjd_sn_delivered, :switches => school::TERMINALS.values.map { |t| t[0] }, :assist => true
    school::TERMINALS.each do |id, t|
      room = at(t[1][0], t[1][0], t[1][1], t[1][1])
      goal = [t[2][0], t[2][1], t[2][0], t[2][1]]
      phase(lambda { room.call && !$game_switches[t[0]] }, :quiet => true, :hint => lambda { school.moves(id) },
            :track => { :event => 12, :label => :rjd_sn_crate, :goal => goal, :goal_label => :rjd_sn_delivery })
    end
    solved { $game_variables[685].to_i >= 27 }
  end
end
