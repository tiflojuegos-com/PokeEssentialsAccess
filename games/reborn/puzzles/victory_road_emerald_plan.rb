# The Emerald Room's plan with the puzzle assist (map 805, up to V521 at 8): its steps, each boulder's pushes to its
# plate, and the refuge from Decidueye's arrow by each tile a step is done from.
module PokeAccess
  module RebornVrEmeraldPlan
    MAP = 805
    TOTAL = 97
    STEPS = [
      [0, :climb, 41, [60, 64], 4, 1, nil], [0, :climb, 40, [51, 62], 4, 2, nil],
      [0, :crystal, 104, [49, 64], 6, 3, [48, 64]], [1, :boulder, 42, nil, nil, 4],
      [2, :lever, 57, [42, 49], 8, 24, nil, true], [2, :boulder, 43, nil, nil, 25],
      [3, :lever, 48, [32, 34], 8, 85, nil, true], [3, :crystal, 85, [28, 26], 6, 86, nil],
      [3, :bounce, 28, [28, 26], nil, 87], [4, :lever, 57, [42, 49], 8, 88, nil, false],
      [4, :lever, 54, [50, 32], 8, 89, nil, true], [4, :crystal, 87, [48, 29], 4, 90, nil],
      [4, :bounce, 48, [48, 29], nil, 91], [5, :lever, 53, [48, 32], 2, 92, nil, true],
      [5, :lever, 56, [34, 53], 8, 93, nil, true], [5, :lever, 50, [36, 36], 8, 94, nil, true],
      [5, :lever, 46, [29, 31], 4, 95, nil, true], [5, :crystal, 86, [37, 27], 4, 96, nil],
      [5, :bounce, 37, [37, 27], nil, 97]
    ]
    ARRIVAL = [
      5962, 6062, 6063, 6064, 6065, 6162, 6163, 6164, 6261, 6262, 6263, 6264, 6361, 6362, 6363, 6460, 6461, 6462,
      6463, 6560, 6561, 6562, 6563, 6661, 6662, 6663, 6763, 6764
    ]
    LEDGE = [
      2466, 2467, 2468, 2469, 2569, 2570, 2670, 2770, 2870, 2871, 2971, 3071, 3171, 3271, 3272, 3371, 3372, 3472,
      3572, 3672, 3772, 3872, 3972, 4072, 4172, 4272, 4372, 4472, 4572, 4671, 4672, 4771, 4871, 4971, 5070, 5071,
      5161, 5162, 5170, 5261, 5262, 5263, 5269, 5270, 5361, 5363, 5364, 5368, 5369, 5461, 5462, 5463, 5464, 5465,
      5466, 5468, 5562, 5563, 5564, 5565, 5566, 5567, 5568, 5662, 5663, 5664, 5665, 5666, 5667, 5763, 5764, 5765,
      5766, 5767, 5864, 5865
    ]
    PUSHES = {
      42 => {
        2639 => [6, 25, 39, 8, nil, nil], 2641 => [6, 25, 41, 10, nil, nil], 2642 => [8, 26, 43, 11, nil, nil],
        2643 => [8, 26, 44, 12, nil, nil], 2644 => [8, 26, 45, 13, nil, nil], 2645 => [8, 26, 46, 14, nil, nil],
        2646 => [8, 26, 47, 15, nil, nil], 2647 => [8, 26, 48, 16, nil, nil], 2648 => [8, 26, 49, 17, nil, nil],
        2649 => [8, 26, 50, 18, nil, nil], 2650 => [8, 26, 51, 19, nil, nil], 2651 => [8, 26, 52, 20, nil, nil],
        2652 => [8, 26, 53, 21, nil, nil], 2653 => [8, 26, 54, 22, nil, nil], 2739 => [6, 26, 39, 7, nil, nil],
        2741 => [6, 26, 41, 9, nil, nil], 2754 => [6, 26, 54, 22, nil, nil], 2834 => [8, 28, 35, 1, nil, nil],
        2835 => [8, 28, 36, 2, nil, nil], 2836 => [8, 28, 37, 3, nil, nil], 2837 => [8, 28, 38, 4, 27, 39],
        2838 => [8, 28, 39, 5, 27, 39], 2839 => [8, 28, 40, 6, 27, 41], 2840 => [8, 28, 41, 7, 27, 41],
        2841 => [8, 28, 42, 8, nil, nil], 2842 => [8, 28, 43, 9, nil, nil], 2843 => [8, 28, 44, 10, nil, nil],
        2844 => [8, 28, 45, 11, nil, nil], 2845 => [8, 28, 46, 12, nil, nil], 2846 => [8, 28, 47, 13, nil, nil],
        2847 => [8, 28, 48, 14, nil, nil], 2848 => [8, 28, 49, 15, nil, nil], 2849 => [8, 28, 50, 16, nil, nil],
        2850 => [8, 28, 51, 17, 27, 54], 2851 => [8, 28, 52, 18, 27, 54], 2852 => [8, 28, 53, 19, 27, 54],
        2853 => [8, 28, 54, 20, 27, 54], 2854 => [8, 28, 55, 21, nil, nil], 2855 => [8, 28, 56, 22, nil, nil],
        2856 => [8, 28, 57, 23, nil, nil], 2857 => [8, 28, 58, 24, 27, 61], 2858 => [8, 28, 59, 25, 27, 61],
        2859 => [8, 28, 60, 26, 27, 61], 2860 => [8, 28, 61, 27, 27, 61]
      },
      43 => {
        2639 => [6, 25, 39, 83, nil, nil], 2641 => [6, 25, 41, 81, nil, nil], 2642 => [8, 26, 43, 82, nil, nil],
        2643 => [8, 26, 44, 83, nil, nil], 2644 => [8, 26, 45, 84, nil, nil], 2645 => [8, 26, 46, 85, nil, nil],
        2646 => [8, 26, 47, 86, nil, nil], 2647 => [8, 26, 48, 87, nil, nil], 2648 => [8, 26, 49, 88, nil, nil],
        2649 => [8, 26, 50, 89, nil, nil], 2650 => [8, 26, 51, 90, nil, nil], 2651 => [8, 26, 52, 91, nil, nil],
        2652 => [8, 26, 53, 92, nil, nil], 2653 => [8, 26, 54, 93, nil, nil], 2660 => [2, 26, 59, 62, nil, nil],
        2661 => [2, 26, 60, 61, nil, nil], 2662 => [2, 26, 61, 60, nil, nil], 2663 => [6, 25, 63, 59, nil, nil],
        2664 => [6, 25, 64, 60, nil, nil], 2739 => [6, 26, 39, 82, nil, nil], 2741 => [6, 26, 41, 80, nil, nil],
        2754 => [6, 26, 54, 67, nil, nil], 2761 => [6, 26, 61, 60, nil, nil], 2762 => [2, 27, 61, 59, 26, 61],
        2763 => [6, 26, 63, 58, nil, nil], 2764 => [8, 27, 65, 59, 28, 65], 2835 => [2, 28, 34, 85, nil, nil],
        2836 => [2, 28, 35, 84, nil, nil], 2837 => [2, 28, 36, 83, nil, nil], 2838 => [2, 28, 37, 82, nil, nil],
        2839 => [2, 28, 38, 81, nil, nil], 2840 => [2, 28, 39, 80, 27, 39], 2841 => [2, 28, 40, 79, 27, 39],
        2842 => [2, 28, 41, 78, 27, 41], 2843 => [2, 28, 42, 77, 27, 41], 2844 => [2, 28, 43, 76, nil, nil],
        2845 => [2, 28, 44, 75, nil, nil], 2846 => [2, 28, 45, 74, nil, nil], 2847 => [2, 28, 46, 73, nil, nil],
        2848 => [2, 28, 47, 72, nil, nil], 2849 => [2, 28, 48, 71, nil, nil], 2850 => [2, 28, 49, 70, nil, nil],
        2851 => [2, 28, 50, 69, nil, nil], 2852 => [2, 28, 51, 68, nil, nil], 2853 => [2, 28, 52, 67, nil, nil],
        2854 => [2, 28, 53, 66, nil, nil], 2855 => [2, 28, 54, 65, 27, 54], 2856 => [2, 28, 55, 64, 27, 54],
        2857 => [2, 28, 56, 63, nil, nil], 2858 => [2, 28, 57, 62, nil, nil], 2859 => [2, 28, 58, 61, nil, nil],
        2860 => [2, 28, 59, 60, nil, nil], 2861 => [6, 27, 61, 59, 26, 61], 2863 => [6, 27, 63, 57, 26, 63],
        2864 => [8, 28, 65, 58, 27, 65], 2961 => [6, 28, 61, 58, 27, 61], 2962 => [2, 29, 61, 57, 28, 61],
        2963 => [6, 28, 63, 56, 27, 63], 2964 => [6, 28, 64, 57, 27, 64], 3060 => [2, 30, 59, 58, nil, nil],
        3061 => [2, 30, 60, 57, nil, nil], 3062 => [6, 29, 62, 56, 28, 63], 3063 => [6, 29, 63, 55, 28, 63],
        3064 => [6, 29, 64, 56, 28, 64], 3162 => [6, 30, 62, 55, 29, 62], 3163 => [6, 30, 63, 54, 29, 63],
        3164 => [8, 31, 65, 55, 32, 65], 3165 => [8, 31, 66, 56, nil, nil], 3251 => [2, 32, 50, 65, 33, 50],
        3252 => [2, 32, 51, 64, 33, 50], 3253 => [2, 32, 52, 63, nil, nil], 3254 => [2, 32, 53, 62, nil, nil],
        3255 => [2, 32, 54, 61, nil, nil], 3256 => [2, 32, 55, 60, nil, nil], 3257 => [2, 32, 56, 59, nil, nil],
        3258 => [2, 32, 57, 58, nil, nil], 3259 => [2, 32, 58, 57, nil, nil], 3260 => [2, 32, 59, 56, nil, nil],
        3261 => [2, 32, 60, 55, nil, nil], 3262 => [2, 32, 61, 54, nil, nil], 3263 => [6, 31, 63, 53, 30, 63],
        3264 => [8, 32, 65, 54, 31, 65], 3265 => [8, 32, 66, 55, nil, nil], 3363 => [6, 32, 63, 52, 31, 63],
        3462 => [2, 34, 61, 52, nil, nil], 3463 => [6, 33, 63, 51, 32, 63], 3563 => [6, 34, 63, 50, 33, 63],
        3652 => [2, 36, 51, 60, 35, 51], 3653 => [2, 36, 52, 59, 35, 51], 3654 => [2, 36, 53, 58, nil, nil],
        3655 => [2, 36, 54, 57, nil, nil], 3656 => [2, 36, 55, 56, nil, nil], 3657 => [2, 36, 56, 55, nil, nil],
        3658 => [2, 36, 57, 54, nil, nil], 3659 => [2, 36, 58, 53, nil, nil], 3660 => [2, 36, 59, 52, nil, nil],
        3661 => [2, 36, 60, 51, nil, nil], 3662 => [2, 36, 61, 50, nil, nil], 3663 => [6, 35, 63, 49, 34, 63],
        3762 => [6, 36, 62, 47, 35, 63], 3763 => [6, 36, 63, 48, 35, 63], 3861 => [2, 38, 60, 47, nil, nil],
        3862 => [6, 37, 62, 46, 36, 62], 3863 => [8, 38, 64, 47, 39, 64], 3962 => [6, 38, 62, 45, 37, 62],
        3963 => [8, 39, 64, 46, 38, 64], 3964 => [6, 38, 64, 47, 37, 63], 4027 => [2, 40, 26, 79, nil, nil],
        4028 => [2, 40, 27, 78, nil, nil], 4029 => [2, 40, 28, 77, nil, nil], 4030 => [2, 40, 29, 76, nil, nil],
        4031 => [2, 40, 30, 75, nil, nil], 4032 => [2, 40, 31, 74, nil, nil], 4033 => [2, 40, 32, 73, nil, nil],
        4034 => [2, 40, 33, 72, nil, nil], 4035 => [2, 40, 34, 71, nil, nil], 4036 => [2, 40, 35, 70, nil, nil],
        4037 => [2, 40, 36, 69, nil, nil], 4038 => [2, 40, 37, 68, nil, nil], 4039 => [2, 40, 38, 67, nil, nil],
        4040 => [2, 40, 39, 66, nil, nil], 4041 => [2, 40, 40, 65, nil, nil], 4042 => [2, 40, 41, 64, nil, nil],
        4043 => [2, 40, 42, 63, nil, nil], 4044 => [2, 40, 43, 62, nil, nil], 4045 => [2, 40, 44, 61, nil, nil],
        4046 => [2, 40, 45, 60, nil, nil], 4047 => [2, 40, 46, 59, nil, nil], 4048 => [2, 40, 47, 58, nil, nil],
        4049 => [2, 40, 48, 57, nil, nil], 4050 => [2, 40, 49, 56, nil, nil], 4051 => [2, 40, 50, 55, nil, nil],
        4052 => [2, 40, 51, 54, nil, nil], 4053 => [2, 40, 52, 53, nil, nil], 4054 => [2, 40, 53, 52, nil, nil],
        4055 => [2, 40, 54, 51, nil, nil], 4056 => [2, 40, 55, 50, nil, nil], 4057 => [2, 40, 56, 49, nil, nil],
        4058 => [2, 40, 57, 48, nil, nil], 4059 => [2, 40, 58, 47, nil, nil], 4060 => [2, 40, 59, 46, nil, nil],
        4061 => [2, 40, 60, 45, nil, nil], 4062 => [6, 39, 62, 44, 38, 62], 4064 => [6, 39, 64, 46, 38, 64],
        4162 => [6, 40, 62, 43, 39, 62], 4163 => [8, 41, 64, 44, 40, 64], 4164 => [8, 41, 65, 45, 42, 65],
        4261 => [2, 42, 60, 43, nil, nil], 4262 => [6, 41, 62, 42, 40, 62], 4263 => [8, 42, 64, 43, 41, 64],
        4264 => [8, 42, 65, 44, 41, 65], 4362 => [6, 42, 62, 41, 41, 62], 4363 => [8, 43, 64, 42, 42, 64],
        4364 => [8, 43, 65, 43, 42, 65], 4427 => [6, 43, 27, 3, nil, nil], 4428 => [8, 44, 29, 4, nil, nil],
        4429 => [8, 44, 30, 5, nil, nil], 4430 => [8, 44, 31, 6, nil, nil], 4431 => [8, 44, 32, 7, nil, nil],
        4432 => [8, 44, 33, 8, nil, nil], 4433 => [8, 44, 34, 9, nil, nil], 4434 => [8, 44, 35, 10, 43, 35],
        4435 => [8, 44, 36, 11, 43, 36], 4436 => [8, 44, 37, 12, 43, 37], 4437 => [8, 44, 38, 13, nil, nil],
        4438 => [8, 44, 39, 14, nil, nil], 4439 => [8, 44, 40, 15, nil, nil], 4440 => [8, 44, 41, 16, nil, nil],
        4441 => [8, 44, 42, 17, nil, nil], 4442 => [8, 44, 43, 18, nil, nil], 4443 => [8, 44, 44, 19, 43, 46],
        4444 => [8, 44, 45, 20, 43, 46], 4445 => [8, 44, 46, 21, 43, 46], 4446 => [8, 44, 47, 22, 43, 47],
        4447 => [8, 44, 48, 23, nil, nil], 4448 => [8, 44, 49, 24, nil, nil], 4449 => [8, 44, 50, 25, nil, nil],
        4450 => [8, 44, 51, 26, 45, 54], 4451 => [8, 44, 52, 27, 45, 54], 4452 => [8, 44, 53, 28, 45, 54],
        4453 => [8, 44, 54, 29, 45, 54], 4454 => [8, 44, 55, 30, 45, 55], 4459 => [2, 44, 58, 43, 45, 58],
        4460 => [2, 44, 59, 42, 45, 59], 4461 => [2, 44, 60, 41, 45, 60], 4462 => [6, 43, 62, 40, 42, 62],
        4463 => [8, 44, 64, 41, 43, 64], 4464 => [4, 45, 64, 44, 46, 64], 4527 => [6, 44, 27, 2, nil, nil],
        4554 => [4, 46, 54, 31, 47, 54], 4555 => [8, 45, 56, 32, 46, 56], 4556 => [8, 45, 57, 33, 46, 57],
        4557 => [8, 45, 58, 34, 44, 58], 4558 => [8, 45, 59, 35, 44, 59], 4559 => [8, 45, 60, 36, 44, 60],
        4560 => [8, 45, 61, 37, 44, 61], 4561 => [8, 45, 62, 38, 44, 62], 4562 => [8, 45, 63, 39, 44, 63],
        4563 => [8, 45, 64, 40, 44, 64], 4564 => [4, 46, 64, 45, 47, 65], 4627 => [6, 45, 27, 1, nil, nil],
        4653 => [2, 46, 52, 33, nil, nil], 4654 => [4, 47, 54, 32, 48, 54], 4655 => [8, 46, 56, 33, 45, 56],
        4656 => [8, 46, 57, 34, 45, 57], 4657 => [8, 46, 58, 35, 45, 58], 4658 => [4, 47, 58, 36, 48, 58],
        4754 => [4, 48, 54, 33, 47, 55], 4755 => [4, 48, 55, 34, 47, 57], 4757 => [4, 48, 57, 36, 47, 58],
        4758 => [4, 48, 58, 37, 49, 60]
      }
    }
    BOULDERS = { 42 => [1230, 4, 20], 43 => [1231, 25, 60] }
    LEVERS = { 46 => 1232, 48 => 1233, 50 => 1234, 53 => 1235, 54 => 1236, 56 => 1237, 57 => 1238 }
    CRYSTALS = { 104 => 2131, 85 => 1240, 86 => 1241, 87 => 1242 }
    PHASE_SWITCH = [nil, 1230, 1231, 1257, 1259, 1258]
    BOUNCES = { 28 => [25, 1240, 1257], 37 => [26, 1241, 1258], 48 => [28, 1242, 1259] }
    RESET_AT = [64, 59]
    SAFE_ROW = 66
    FIRE_COLUMNS = [27, 50]
    REACT_FRAMES = 24

    # A list of tiles (x * 100 + y) as a set.
    def self.set_of(list)
      h = {}
      list.each { |t| h[t] = true }
      h
    end

    def self.arrival; @arrival ||= set_of(ARRIVAL); end

    def self.ledge; @ledge ||= set_of(LEDGE); end

    # Whether the room has gone past a phase: the first crystal (V521 at 2), a plate, a bounce.
    def self.phase_done?(ph)
      ph.zero? ? $game_variables[521].to_i >= 2 : $game_switches[PHASE_SWITCH[ph]]
    end

    # A plan step as what the assist tells: [kind, event, tile to stand on, facing, number, refuge, pushes left].
    def self.told(s)
      [s[1], s[2], s[3], s[4], s[5], s[6], nil]
    end

    # The push a boulder needs from where it stands, or the way out to reset it when no push takes it home.
    def self.push_step(s)
      ev = $game_map.events[s[2]]
      return nil unless ev
      row = PUSHES[s[2]][ev.x * 100 + ev.y]
      return [:reset, s[2], RESET_AT, 8, nil, nil, nil] unless row
      _flag, first, total = BOULDERS[s[2]]
      n = first + [total - row[3], 0].max
      [:push, s[2], [row[1], row[2]], row[0], n, row[4] && [row[4], row[5]], row[3]]
    end

    # The step to take now, by the phase and what of it is done: the climb out on the arrival or the ledge below the
    # second wall, unless a boulder must be reset first; nil out of the room or once done.
    def self.target
      return nil unless $game_map && $game_player && $game_map.map_id == MAP
      return nil if $game_variables[521].to_i >= 8
      ph = (0...PHASE_SWITCH.length).find { |p| !phase_done?(p) }
      return nil unless ph
      step = phase_step(ph)
      return step if step && step[0] == :reset
      at = $game_player.x * 100 + $game_player.y
      climb = arrival[at] ? STEPS[0] : ledge[at] ? STEPS[1] : nil
      return step unless climb
      out = told(climb)
      out[4] = nil unless ph.zero?
      out
    end

    # The next step of a phase: its first lever not yet as the plan needs it, crystal not lit, boulder push or bounce.
    def self.phase_step(ph)
      STEPS.each do |s|
        next unless s[0] == ph && s[1] != :climb
        case s[1]
        when :boulder then return push_step(s)
        when :lever then next if $game_switches[LEVERS[s[2]]] == s[7]
        when :crystal then next if $game_switches[CRYSTALS[s[2]]]
        end
        return told(s)
      end
      nil
    end

    # Where the player has to stand for the next step.
    def self.next_at
      t = target
      t && t[2]
    end

    # The next step, in words: what to use or push and which way to face.
    def self.next_label
      t = target
      return nil unless t
      dir = t[3] && PokeAccess::Puzzles.face_name(t[3])
      case t[0]
      when :climb then PokeAccess::I18n.t(:rbrg_climb, :dir => dir)
      when :crystal then PokeAccess::I18n.t(:rbrg_crystal, :dir => dir)
      when :lever then PokeAccess::I18n.t(:rbrg_lever, :dir => dir)
      when :push then PokeAccess::I18n.t(:rbrg_push, :dir => dir, :left => t[6])
      when :bounce then PokeAccess::I18n.t(:rbrg_bounce)
      else PokeAccess::I18n.t(:rbrg_reset)
      end
    end

    # The info key's line with the assist: the step's number and what it is, and where from the player.
    def self.info_line
      return nil unless PokeAccess::Puzzles.assist?
      t = target
      return nil unless t
      where = PokeAccess::Locator.dir_phrase(t[2][0] - $game_player.x, t[2][1] - $game_player.y)
      what = next_label
      line = if t[4]
               PokeAccess::I18n.t(:rbg_plan_step, :n => t[4], :total => TOTAL, :what => what, :where => where)
             else
               PokeAccess::I18n.t(:rbg_plan_off, :what => what, :where => where)
             end
      hurry?(t) ? PokeAccess.sentences([line, PokeAccess::I18n.t(:rbrg_hurry)]) : line
    end

    # Whether Decidueye can shoot down this tile: it follows the player between columns 27 and 50, and an arrow never
    # hurts from row 66 down.
    def self.under_fire?(x, y)
      x.between?(FIRE_COLUMNS[0], FIRE_COLUMNS[1]) && y < SAFE_ROW
    end

    # Whether a step is done where an arrow leaves no time to step aside: under fire, out of a crystal's shelter and
    # with no refuge reached before the arrow.
    def self.hurry?(t)
      x, y = t[2]
      t[5].nil? && under_fire?(x, y) && !shielded?(x, y)
    end

    # Whether an arrow down this tile's column turns back at the blister beside a lit crystal before it gets there; the
    # arrow starts 22 rows above the player.
    def self.shielded?(x, y)
      b = BOUNCES[x]
      !b.nil? && $game_switches[b[1]] && !$game_switches[b[2]] && y > b[0] && y <= b[0] + 21
    end

    # Whether a walker going this many rows down (up, when negative) from row y before stepping aside gets there ahead
    # of the arrow, with REACT_FRAMES to spare: the arrow falls a row every 2 frames, a walker 8.
    def self.in_time?(y, rows)
      2 * (y - [y - 22, 22].max - 1 + rows) - 8 * rows.abs >= REACT_FRAMES
    end

    # With the assist, what to do as an arrow falls down the player's column: stay under a crystal that sends it back;
    # else, standing by the step at hand, go to its refuge if it is reached in time; else just leave the column.
    def self.dodge_line
      x = $game_player.x
      y = $game_player.y
      return PokeAccess::I18n.t(:rbrg_stay) if shielded?(x, y)
      t = target
      rf = t && t[5]
      near = rf && (t[2][0] - x).abs + (t[2][1] - y).abs <= 2 && in_time?(y, rf[1] - y)
      if near && (rf[0] != x || rf[1] >= SAFE_ROW)
        where = PokeAccess::Locator.dir_phrase(rf[0] - x, rf[1] - y)
        return PokeAccess::I18n.t(:rbrg_refuge, :where => where)
      end
      PokeAccess::I18n.t(:rb3_dodge_column)
    end

    GATES = { 44 => [1230, true], 45 => [1231, true], 47 => [1232, true], 49 => [1233, true], 51 => [1234, true],
              52 => [1235, true], 55 => [1236, true], 58 => [1237, true], 59 => [1238, true], 60 => [1237, false],
              61 => [1238, false] }
    PLATES = [[[28, 33], 1230], [[47, 27], 1231]]

    # A gate's name with whether it stands open, as its lever or plate leaves it.
    def self.gate_label(ev)
      sw, open_on = GATES[ev.id]
      PokeAccess::I18n.t($game_switches[sw] == open_on ? :rbrg_gate_open : :rbrg_gate_closed)
    end
  end
end

PokeAccess::Game.define("reborn") do
  plan = PokeAccess::RebornVrEmeraldPlan
  mechanic(:state, plan::MAP, :part => :emerald_room) do
    auto
    name plan::GATES.keys, lambda { |ev| plan.gate_label(ev) }
    plan::PLATES.each do |at, sw|
      spot :at => at, :label => :rbc_vr_plate, :onto => true, :when => lambda { !$game_switches[sw] }
    end
  end

  mechanic(:state, plan::MAP, :part => :emerald_plan) do
    auto
    spot :at => lambda { plan.next_at }, :label => lambda { plan.next_label }, :onto => true, :assist => true
    info { plan.info_line }
    active { PokeAccess::Puzzles.assist? && !plan.target.nil? }
    hint :rbrg_hint
  end
end
