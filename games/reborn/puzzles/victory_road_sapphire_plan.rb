# The Sapphire Room's plan with the puzzle assist (map 804, to the way down to B5F): for each number of crystals lit, the
# event to use next from each ground the player can walk and slide over, with its step on the plan.
module PokeAccess
  module RebornVrSapphirePlan
    MAP = 804
    CHAIN = [1218, 1219, 1220, 1222, 1225, 1221, 1223, 1224]
    CRYSTALS = [27, 31, 32, 35, 41, 33, 37, 39]
    EXIT = 3
    STEPS = 34
    GROUNDS = [
      [
        [6, 1, [63, 69, 64, 69, 66, 63]], [7, 2, [64, 59, 64, 63]], [27, 3, [54, 64, 62, 59]],
        [8, nil, [52, 64]]
      ],
      [
        [8, 4, [43, 63, 44, 62, 54, 64, 62, 59]], [23, 5, [40, 66, 52, 64]], [9, 6, [36, 65, 37, 65]],
        [11, 7, [22, 69, 34, 65]], [31, 8, [20, 69, 29, 69]], [6, nil, [63, 69, 64, 69, 66, 63]],
        [7, nil, [64, 59, 64, 63]], [43, nil, [31, 69, 37, 70]], [44, nil, [35, 70]]
      ],
      [
        [11, 9, [18, 68, 19, 69, 20, 69, 29, 69]], [10, 10, [22, 69, 24, 61, 34, 65]], [32, 11, [24, 59]],
        [6, nil, [63, 69, 64, 69, 66, 63]], [7, nil, [64, 59, 64, 63]], [8, nil, [54, 64, 62, 59]],
        [9, nil, [36, 65, 37, 65]], [23, nil, [40, 66, 52, 64]], [43, nil, [31, 69, 37, 70]],
        [44, nil, [35, 70]]
      ],
      [
        [10, 12, [22, 58, 24, 59]], [21, 13, [18, 60, 22, 69, 24, 61, 34, 65]], [14, 14, [18, 57, 64, 47]],
        [13, 15, [62, 47, 62, 48]], [26, 16, [56, 26, 60, 48]], [35, 17, [53, 25]],
        [6, nil, [63, 69, 64, 69, 66, 63]], [7, nil, [64, 59, 64, 63]], [8, nil, [54, 64, 62, 59]],
        [9, nil, [36, 65, 37, 65]], [11, nil, [20, 69, 29, 69]], [23, nil, [40, 66, 52, 64]],
        [43, nil, [31, 69, 37, 70]], [44, nil, [35, 70]]
      ],
      [
        [25, 18, [52, 23, 53, 25]], [17, 19, [31, 15, 56, 26, 60, 48]], [41, 20, [29, 15]],
        [6, nil, [63, 69, 64, 69, 66, 63]], [7, nil, [64, 59, 64, 63]], [8, nil, [54, 64, 62, 59]],
        [9, nil, [36, 65, 37, 65]], [10, nil, [24, 59]], [11, nil, [20, 69, 29, 69]],
        [13, nil, [62, 47, 62, 48]], [14, nil, [18, 57, 64, 47]], [21, nil, [18, 60, 22, 69, 24, 61, 34, 65]],
        [23, nil, [40, 66, 52, 64]], [43, nil, [31, 69, 37, 70]], [44, nil, [35, 70]]
      ],
      [
        [17, 21, [29, 15]], [12, 22, [31, 15, 42, 51, 56, 26, 60, 48]], [33, 23, [44, 51]],
        [6, nil, [63, 69, 64, 69, 66, 63]], [7, nil, [64, 59, 64, 63]], [8, nil, [54, 64, 62, 59]],
        [9, nil, [36, 65, 37, 65]], [10, nil, [24, 59]], [11, nil, [20, 69, 29, 69]],
        [13, nil, [62, 47, 62, 48]], [14, nil, [18, 57, 64, 47]], [21, nil, [18, 60, 22, 69, 24, 61, 34, 65]],
        [23, nil, [40, 66, 52, 64]], [25, nil, [53, 25]], [43, nil, [31, 69, 37, 70]],
        [44, nil, [35, 70]]
      ],
      [
        [12, 24, [44, 51, 51, 48, 52, 47]], [16, 25, [31, 15, 34, 34, 42, 51, 56, 26, 60, 48]], [37, 26, [36, 34]],
        [6, nil, [63, 69, 64, 69, 66, 63]], [7, nil, [64, 59, 64, 63]], [8, nil, [54, 64, 62, 59]],
        [9, nil, [36, 65, 37, 65]], [10, nil, [24, 59]], [11, nil, [20, 69, 29, 69]],
        [13, nil, [62, 47, 62, 48]], [14, nil, [18, 57, 64, 47]], [17, nil, [29, 15]],
        [21, nil, [18, 60, 22, 69, 24, 61, 34, 65]], [23, nil, [40, 66, 52, 64]], [25, nil, [53, 25]],
        [43, nil, [31, 69, 37, 70]], [44, nil, [35, 70]]
      ],
      [
        [16, 27, [36, 34, 36, 36]], [15, 28, [17, 45, 31, 15, 34, 34, 42, 51, 56, 26, 60, 48]], [39, 29, [15, 45]],
        [6, nil, [63, 69, 64, 69, 66, 63]], [7, nil, [64, 59, 64, 63]], [8, nil, [54, 64, 62, 59]],
        [9, nil, [36, 65, 37, 65]], [10, nil, [24, 59]], [11, nil, [20, 69, 29, 69]],
        [12, nil, [44, 51]], [13, nil, [62, 47, 62, 48]], [14, nil, [18, 57, 64, 47]],
        [17, nil, [29, 15]], [21, nil, [18, 60, 22, 69, 24, 61, 34, 65]], [23, nil, [40, 66, 52, 64]],
        [25, nil, [53, 25]], [43, nil, [31, 69, 37, 70]], [44, nil, [35, 70]]
      ],
      [
        [15, 30, [14, 44, 15, 45]], [19, 31, [17, 45, 19, 25, 31, 15, 34, 34, 42, 51, 56, 26, 60, 48]],
        [18, 32, [19, 23, 25, 17]], [20, 33, [17, 13, 23, 17]], [3, 34, [13, 11, 14, 11, 15, 13]],
        [6, nil, [63, 69, 64, 69, 66, 63]], [7, nil, [64, 59, 64, 63]], [8, nil, [54, 64, 62, 59]],
        [9, nil, [36, 65, 37, 65]], [10, nil, [24, 59]], [11, nil, [20, 69, 29, 69]], [12, nil, [44, 51]],
        [13, nil, [62, 47, 62, 48]], [14, nil, [18, 57, 64, 47]], [16, nil, [36, 34]],
        [17, nil, [29, 15]], [21, nil, [18, 60, 22, 69, 24, 61, 34, 65]], [23, nil, [40, 66, 52, 64]],
        [25, nil, [53, 25]], [43, nil, [31, 69, 37, 70]], [44, nil, [35, 70]]
      ]
    ]

    # For each number of crystals lit, the tile the player comes into a ground on => [event, step].
    def self.index
      @index ||= GROUNDS.map do |grounds|
        h = {}
        grounds.each { |ev, n, tiles| tiles.each_slice(2) { |x, y| h[[x, y]] = [ev, n] } }
        h
      end
    end

    # How many crystals are lit, in their only order; nil for a set out of it.
    def self.phase
      n = 0
      n += 1 while n < CHAIN.length && $game_switches[CHAIN[n]]
      CHAIN[n..-1].any? { |s| $game_switches[s] } ? nil : n
    end

    # Notes the ground the player stands on when they stand still on a tile that tells it, and keeps it while they
    # walk and slide over it.
    def self.observe
      return unless $game_map && $game_player && $game_map.map_id == MAP
      return if ($game_player.moving? rescue false) || ($PokemonGlobal.sliding rescue false)
      ph = phase
      at = [$game_player.x, $game_player.y]
      return if @seen == [ph, at]
      @seen = [ph, at]
      hit = ph && index[ph][at]
      @ground = [ph, hit] if hit
    end

    # Forgets the ground, on a new map.
    def self.forget
      @seen = nil
      @ground = nil
    end

    # What to do next as [event, step]: the ground's own when it is known for the crystals lit now, else the next
    # crystal (or the way out) with no step; nil out of the room or with the crystals out of their order.
    def self.target
      return nil unless $game_map && $game_map.map_id == MAP
      observe
      ph = phase
      return nil unless ph
      return @ground[1] if @ground && @ground[0] == ph
      [CRYSTALS[ph] || EXIT, nil]
    end

    # Where the next thing to do stands.
    def self.next_at
      t = target
      ev = t && $game_map.events[t[0]]
      ev && [ev.x, ev.y]
    end

    # The next thing to do, in words.
    def self.next_label
      t = target
      return nil unless t
      key = if t[0] == EXIT then :rbra_ice_exit
            elsif CRYSTALS.include?(t[0]) then :rbra_ice_crystal
            else :rbra_ice_climb
            end
      PokeAccess::I18n.t(key)
    end

    # The info key's line with the assist: the step's number and what it is, and where from the player.
    def self.info_line
      return nil unless PokeAccess::Puzzles.assist?
      t = target
      at = next_at
      return nil unless t && at
      where = PokeAccess::Locator.dir_phrase(at[0] - $game_player.x, at[1] - $game_player.y)
      what = next_label
      return PokeAccess::I18n.t(:rbg_plan_off, :what => what, :where => where) unless t[1]
      PokeAccess::I18n.t(:rbg_plan_step, :n => t[1], :total => STEPS, :what => what, :where => where)
    end

    PokeAccess::Frame.each_pulse { PokeAccess::RebornVrSapphirePlan.observe } unless @pulsing
    @pulsing = true
  end
end

PokeAccess::Game.define("reborn") do
  plan = PokeAccess::RebornVrSapphirePlan
  mechanic(:state, plan::MAP, :part => :ice_plan) do
    auto
    spot :at => lambda { plan.next_at }, :label => lambda { plan.next_label }, :assist => true
    info { plan.info_line }
    active { PokeAccess::Puzzles.assist? && !plan.target.nil? }
    hint :rbra_ice_hint
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornVrSapphirePlan.forget }
