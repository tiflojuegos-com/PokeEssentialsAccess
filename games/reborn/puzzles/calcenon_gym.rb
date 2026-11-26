# Calcenon Gym (map 419): three stretches of tiles before Charlotte. A grey tile turns red when first stepped on (self
# switch A, adding one to the count in variable 188, 189 or 190, of 19, 40 and 75); a red one stepped on again, or an
# orange trap, burns and throws the player back to the stretch's first row. A full count shows its stairs.
module PokeAccess
  module RebornCalcenon
    MAP = 419
    STEP = { "U" => [0, -1], "D" => [0, 1], "L" => [-1, 0], "R" => [1, 0] }
    STRETCHES = [
      { :var => 188, :total => 19, :won => 493, :entry => [9, 54], :stairs => 13, :landing => [7, 11, 58, 58],
        :box => [6, 12, 49, 58], :tiles => [11, 14, 15, 16] + (18..32).to_a, :traps => [17, 33],
        :order => "ULLUUURDRDRDRUULUL" },
      { :var => 189, :total => 40, :won => 494, :entry => [9, 43], :stairs => 41, :landing => [5, 13, 46, 46],
        :box => [4, 14, 37, 46], :tiles => [40] + (42..68).to_a + (70..81).to_a, :traps => [34, 35, 36, 37, 38, 69],
        :order => "URURRDRUULURULLDDLULDDLULDDLLURUULURRRR" },
      { :var => 190, :total => 75, :won => 495, :entry => [9, 31], :stairs => 89, :landing => [4, 14, 34, 34],
        :box => [3, 15, 22, 34], :tiles => [90] + (104..177).to_a, :traps => [87] + (91..103).to_a,
        :order => "ULULLDLLURULURURRDDRURDRDDRURURDDRUUULLLULLULLLLLUURRRDRRRDRRDRRUUULDLULLL" }
    ]
    # Charlotte's room hides an optional secret: of 59 hidden tiles (events 178 to 236) 29 add to variable 469 and 30
    # take away; at 29, switch 1033 opens a door behind her.
    SECRET_RIGHT = [225, 224, 220, 221, 222, 223, 235, 236, 233, 234, 232, 228, 227, 226, 229, 230, 231,
                    213, 214, 215, 216, 217, 218, 208, 180, 209, 210, 211, 212]
    SECRET_WRONG = [178, 179] + (181..207).to_a + [219]

    # The stretch's tiles in the order of its solution.
    def self.cells(i)
      @cells ||= {}
      @cells[i] ||= begin
        at = STRETCHES[i][:entry]
        [at] + STRETCHES[i][:order].split("").map { |c| d = STEP[c]; at = [at[0] + d[0], at[1] + d[1]] }
      end
    end

    def self.red?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # The id of the next tile of the solution, or nil when what is red is not where it starts; kept per count and tile.
    def self.next_id(i)
      s = STRETCHES[i]
      n = $game_variables[s[:var]].to_i
      key = [i, n, $game_player.x, $game_player.y]
      @next ||= {}
      return @next[key] if @next.key?(key)
      @next.clear if @next.size > 64
      @next[key] = find_next(i, n)
    end

    # The next tile of the solution while the n red tiles are its first n and the player stands on the last; else nil.
    def self.find_next(i, n)
      s = STRETCHES[i]
      path = cells(i)
      return nil if n >= path.length
      return nil if n > 0 && path[n - 1] != [$game_player.x, $game_player.y]
      done = s[:tiles].select { |id| red?(id) }.map { |id| ev = $game_map.events[id]; ev ? [ev.x, ev.y] : nil }.compact
      return nil unless done.sort == path[0, n].sort
      t = path[n]
      s[:tiles].find { |id| ev = $game_map.events[id]; ev && ev.x == t[0] && ev.y == t[1] }
    end

    # A stretch's assisted line: done once its count is full, the next tile while on the plan, else off the plan.
    def self.hint(i)
      s = STRETCHES[i]
      return :rbb_calc_done if $game_variables[s[:var]].to_i >= s[:total]
      next_id(i) ? :rbb_calc_hint : :rbb_calc_off_plan
    end

    # The next right secret tile, while 29 can still be reached this visit; nil otherwise.
    def self.secret_next
      v = $game_variables[469].to_i
      left = SECRET_RIGHT.reject { |id| red?(id) }
      return nil if v >= 29 || v + left.length < 29
      left.first
    end

    # The secret's assisted line: the next right tile, or that this visit can no longer reach 29.
    def self.secret_hint
      secret_next ? :rbb_calc_secret_hint : :rbb_calc_secret_spoiled
    end
  end
end

PokeAccess::Game.define("reborn") do
  gym = PokeAccess::RebornCalcenon
  gym::STRETCHES.each_with_index do |s, i|
    box = at(*s[:box])
    mechanic(:grid, gym::MAP, :part => "stretch#{i}".to_sym) do
      tiles s[:tiles], :self => "A", :label => :rbb_calc_tile, :count => :rbb_calc_tiles,
                       :words => { true => :rbb_calc_red, false => :rbb_calc_grey }
      hint lambda { gym.hint(i) }
      active { !$game_switches[s[:won]] && box.call }
      solved(nil, :quiet => true) { $game_switches[s[:won]] }
    end
    mechanic(:state, gym::MAP, :part => "path#{i}".to_sym) do
      name s[:traps], :rbb_calc_orange, :when => lambda { |_ev| !$game_switches[s[:won]] }
      avoid s[:traps], :assist => true
      watch :event => s[:stairs], :say => :rbb_calc_stairs_appear
      sent_back :rbb_calc_burned, :events => s[:tiles] + s[:traps], :to => s[:landing], :forced => true
      s[:tiles].each do |id|
        spot :event => id, :label => :puzzle_right_way, :assist => true, :onto => true,
             :when => lambda { box.call && gym.next_id(i) == id }
      end
      active { false }
      solved(nil, :quiet => true) { $game_switches[s[:won]] }
    end
  end
  mechanic(:state, gym::MAP, :part => :rule) do
    arrival_hint :rbb_calc_rule, :once => true
    solved(nil, :quiet => true) { $game_switches[495] }
  end
  mechanic(:state, gym::MAP, :part => :secret) do
    room = at(3, 15, 4, 14)
    avoid gym::SECRET_WRONG, :assist => true
    count :rbb_calc_secret_count, :value => lambda { [$game_variables[469].to_i, 0].max }, :of => 29, :assist => true,
                                  :hide_zero => true, :reset => false
    gym::SECRET_RIGHT.each do |id|
      spot :event => id, :label => :puzzle_right_way, :assist => true, :onto => true,
           :when => lambda { room.call && gym.secret_next == id }
    end
    hint lambda { gym.secret_hint }
    active { PokeAccess::Puzzles.assist? && room.call && !$game_switches[1033] }
    solved(:rbb_calc_secret_open) { $game_switches[1033] }
  end
end
