# Crawli's gym in Kakori (Infested Badge): the lift down (map 65) opens once the grass (variable 720 at 4), water (722
# at 3) and fire (map 154, 721 at 1) sigils are lit. Switch 476 keeps the grass course's two floors. Each way is data:
# per box the player stands in (switches as given; nil, either), the step to take next.
module PokeAccess
  module RejuvKakori
    # [rock, [x, y] stood on, direction walked, [x, y] landed], [:sensor, event, [x, y], direction], [:battle, event] or
    # [:touch, event, [x, y], direction].
    COURSE1 = [
      [5, [10, 64], 6, [12, 64]], [7, [13, 65], 6, [15, 65]], [8, [17, 64], 6, [19, 64]],
      [9, [19, 65], 2, [19, 67]], [10, [19, 67], 6, [21, 67]], [26, [21, 67], 6, [23, 67]],
      [11, [25, 65], 6, [27, 65]], [12, [28, 65], 6, [30, 65]], [13, [30, 66], 2, [30, 68]],
      [14, [30, 68], 6, [32, 68]], [:sensor, 50, [32, 69], 2], [:sensor, 49, [35, 68], 8],
      [17, [34, 67], 8, [34, 65]], [15, [33, 64], 8, [33, 62]], [18, [33, 57], 4, [31, 57]],
      [19, [31, 57], 8, [31, 55]], [:sensor, 54, [32, 56], 2], [:battle, 61],
      [:sensor, 53, [35, 54], 8], [20, [36, 54], 8, [36, 52]], [21, [35, 51], 4, [33, 51]],
      [:touch, 62, [33, 49], 8], [:touch, 64, [33, 45], 8],
      [6, [10, 66], 6, [12, 66]], [:sensor, 23, [10, 66], 8], [10, [20, 66], 2, [20, 68]],
      [9, [18, 66], 6, [20, 66]], [47, [36, 64], 4, [34, 64]], [22, [31, 51], 6, [33, 51]]
    ]
    # [[x0, x1, y0, y1], switch 476, step].
    BOXES1 = [
      [[3, 8, 62, 63], false, 0], [[2, 10, 64, 65], false, 0], [[2, 8, 66, 66], false, 0],
      [[12, 13, 64, 66], false, 1], [[15, 17, 64, 65], false, 2], [[19, 19, 64, 64], false, 3],
      [[19, 19, 65, 65], false, 3], [[19, 20, 67, 68], false, 4], [[21, 21, 67, 67], false, 5],
      [[23, 26, 65, 69], false, 6], [[22, 22, 69, 69], false, 6], [[27, 28, 65, 65], false, 7],
      [[30, 30, 65, 66], false, 8], [[30, 30, 68, 68], false, 9], [[32, 32, 68, 68], false, 10],
      [[27, 37, 64, 69], true, 11], [[34, 35, 67, 68], false, 12], [[33, 34, 64, 65], false, 13],
      [[33, 36, 57, 62], false, 14], [[31, 32, 59, 62], false, 14], [[31, 31, 57, 57], false, 15],
      [[31, 32, 55, 55], false, 16], [[29, 35, 49, 54], true, 17], [[36, 36, 53, 53], true, 17],
      [[29, 33, 55, 56], true, 17], [[30, 32, 57, 58], true, 17], [[37, 37, 48, 56], true, 18],
      [[36, 36, 49, 49], true, 18], [[35, 36, 55, 58], true, 18], [[34, 34, 57, 58], true, 18],
      [[35, 36, 54, 54], false, 19], [[36, 36, 50, 52], false, 20], [[35, 35, 51, 51], false, 20],
      [[33, 33, 50, 50], false, 21], [[33, 33, 51, 51], false, 21], [[30, 37, 44, 49], false, 22],
      [[29, 29, 45, 46], false, 22], [[10, 10, 66, 66], false, 23], [[11, 18, 64, 69], true, 24],
      [[9, 10, 65, 69], true, 24], [[8, 8, 69, 69], true, 24], [[20, 20, 66, 66], false, 25],
      [[18, 18, 66, 66], false, 26], [[36, 36, 64, 64], false, 27], [[31, 31, 51, 52], false, 28],
      [[30, 30, 52, 52], false, 28]
    ]
    PINSIR = 61
    # Map 154: [:log, event, [x, y], facing], [:door, event, [x, y], into map, by event, [x, y] of that door], stair
    # tiles, log jumps and the sigil, as COURSE1.
    COURSE2 = [
      [:log, 13, [14, 13], 2], [:door, 10, [25, 43], 65, 37, [6, 13]],
      [:sensor, 24, [8, 19], 8], [:sensor, 22, [8, 18], 8],
      [18, [12, 18], 6, [14, 18]], [19, [15, 18], 6, [17, 18]],
      [:touch, 38, [12, 10], 8], [:door, 11, [8, 43], 65, 36, [22, 13]], [:sensor, 24, [8, 19], 2]
    ]
    # [[x0, x1, y0, y1], variable 406, switch 816 or nil, step].
    BOXES2 = [
      [[24, 28, 10, 42], 0, nil, 0], [[13, 23, 13, 23], 0, nil, 0], [[12, 12, 14, 15], 0, nil, 0],
      [[11, 11, 15, 15], 0, nil, 0], [[23, 23, 27, 40], 0, nil, 0], [[22, 22, 28, 39], 0, nil, 0],
      [[16, 21, 29, 41], 0, nil, 0], [[15, 15, 30, 37], 0, nil, 0], [[6, 14, 31, 35], 0, nil, 0],
      [[11, 14, 36, 41], 0, nil, 0], [[24, 28, 10, 42], 1, nil, 1], [[13, 17, 13, 15], 1, nil, 1],
      [[23, 23, 13, 40], 1, nil, 1], [[12, 12, 14, 15], 1, nil, 1], [[11, 11, 15, 15], 1, nil, 1],
      [[13, 16, 16, 16], 1, nil, 1], [[14, 15, 17, 17], 1, nil, 1], [[21, 22, 18, 39], 1, nil, 1],
      [[16, 20, 29, 41], 1, nil, 1], [[15, 15, 30, 37], 1, nil, 1], [[6, 14, 31, 35], 1, nil, 1],
      [[11, 14, 36, 41], 1, nil, 1], [[14, 15, 18, 18], 1, false, 1], [[7, 14, 20, 28], 1, true, 2],
      [[5, 5, 34, 37], 1, true, 2], [[6, 9, 36, 42], 1, true, 2], [[7, 8, 19, 19], 1, nil, 3],
      [[7, 14, 20, 28], 1, false, 3], [[5, 5, 34, 37], 1, false, 3], [[6, 9, 36, 42], 1, false, 3],
      [[9, 12, 16, 19], 1, nil, 4], [[6, 8, 17, 18], 1, nil, 4], [[5, 5, 18, 18], 1, nil, 4],
      [[14, 15, 18, 18], 1, true, 5], [[11, 14, 9, 9], 1, nil, 6], [[9, 19, 10, 12], 1, nil, 6],
      [[19, 19, 13, 17], 1, nil, 6], [[18, 18, 16, 17], 1, nil, 6], [[17, 17, 17, 18], 1, nil, 6],
      [[7, 8, 19, 28], 0, nil, 7], [[12, 14, 25, 26], 0, nil, 7], [[11, 12, 27, 27], 0, nil, 7],
      [[9, 11, 28, 28], 0, nil, 7], [[5, 5, 34, 37], 0, nil, 7], [[6, 9, 36, 42], 0, nil, 7],
      [[9, 12, 16, 19], 0, nil, 8], [[6, 8, 17, 18], 0, nil, 8], [[5, 5, 18, 18], 0, nil, 8]
    ]
    WORDS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }
    STAIRS1 = [23, 24, 25, 48, 49, 50, 51, 52, 53, 54, 55]
    STAIRS2 = [21, 22, 23, 24]

    def self.var(id)
      $game_variables[id].to_i
    end

    # True while the player stands in the box.
    def self.inside?(box)
      x0, x1, y0, y1 = box
      $game_player.x.between?(x0, x1) && $game_player.y.between?(y0, y1)
    end

    # The grass course's next step by where the player stands and which floor is up, past the Pinsir once it is gone;
    # nil outside the course or once its sigil is lit.
    def self.grass_step
      return nil if var(720) >= 4
      up = $game_switches[476] ? true : false
      row = BOXES1.find { |box, sw, _s| sw == up && inside?(box) }
      return nil unless row
      step = row[2]
      step == 17 && gone?(PINSIR) ? 18 : step
    end

    # The fire course's next step, as grass_step.
    def self.fire_step
      return nil if var(721) >= 1
      log = var(406)
      stairs = $game_switches[816] ? true : false
      row = BOXES2.find { |box, v, sw, _s| v == log && (sw.nil? || sw == stairs) && inside?(box) }
      row ? row[3] : nil
    end

    # True once an event is erased, or absent.
    def self.gone?(id)
      ev = $game_map.events[id]
      ev.nil? || PokeAccess.ivar(ev, :@erased) ? true : false
    end

    # The event a step is taken on.
    def self.event_of(step)
      step[0].is_a?(Symbol) ? step[1] : step[0]
    end

    # A step said: where to stand and which way to go, by its kind.
    def self.say(step)
      kind = step[0]
      return [:rj_kakori_pinsir, {}] if kind == :battle
      if kind == :door
        return [:rj_kakori_door, { :x => step[2][0], :y => step[2][1], :dx => step[5][0], :dy => step[5][1] }]
      end
      dir = PokeAccess::I18n.t(WORDS[kind.is_a?(Symbol) ? step[3] : step[2]])
      x, y = kind.is_a?(Symbol) ? step[2] : step[1]
      case kind
      when :sensor then [:rj_kakori_stairs, { :x => x, :y => y, :dir => dir }]
      when :touch then [:rj_kakori_touch, { :x => x, :y => y, :dir => dir }]
      when :log then [:rj_kakori_log, { :x => x, :y => y, :dir => dir }]
      else [:rj_kakori_jump, { :x => x, :y => y, :dir => dir, :lx => step[3][0], :ly => step[3][1] }]
      end
    end

    # How many sigils are lit.
    def self.sigils
      [var(720) >= 4, var(722) >= 3, var(721) >= 1].select { |lit| lit }.length
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  gym = PokeAccess::RejuvKakori
  assist = lambda { PokeAccess::Puzzles.assist? }
  mechanic(:state, 65, :part => :courses) do
    auto
    not_control gym::STAIRS1
    count :rj_kakori_sigils, :value => lambda { gym.sigils }, :of => 3
    gym::COURSE1.each_with_index do |step, i|
      phase lambda { assist.call && gym.grass_step == i }, :hint => lambda { gym.say(step) },
            :hidden => right_way(gym.event_of(step))
    end
    phase lambda { assist.call && gym.var(722) == 1 }, :hint => :rj_kakori_rowlet, :hidden => right_way(71)
    phase lambda { assist.call && gym.var(722) == 2 }, :hint => :rj_kakori_dartrix, :hidden => right_way(73, 67)
    phase lambda { gym.sigils < 3 }
    solved { gym.sigils >= 3 }
  end
  mechanic(:state, 154, :part => :fire) do
    auto
    not_control gym::STAIRS2
    right_choice 13, :takes => { :var => 406 }
    gym::COURSE2.each_with_index do |step, i|
      phase lambda { assist.call && gym.fire_step == i }, :hint => lambda { gym.say(step) },
            :hidden => right_way(gym.event_of(step))
    end
    solved { gym.var(721) >= 1 }
  end
end
