# Glass Workstation (map 732), Glaceon's part: molten glass (tile 620, a wall) cuts eight floor channels (variables 396
# to 403) and four catwalk gaps (switches 940 to 943); with Glaceon following (switch 946) the action button facing one
# freezes the pair for good. Channels 396, 398, 399 and 400 lead to the west door's battle (story 391, 20 to 21).
module PokeAccess
  module RebornGlassPaths
    CHANNELS = { 396 => [77, 78], 397 => [79, 80], 398 => [87, 88], 399 => [89, 90],
                 400 => [91, 92], 401 => [81, 82], 402 => [83, 84], 403 => [85, 86] }
    RAILS = { 940 => [6, 7], 941 => [8, 9], 942 => [10, 11], 943 => [16, 17] }
    CHAIN = [[396, :rbb_glass_hint_channel1], [398, :rbb_glass_hint_channel2],
             [399, :rbb_glass_hint_channel3], [400, :rbb_glass_hint_channel4]]
    RAIL_CHAIN = [[941, :rbb_glass_hint_rail1], [943, :rbb_glass_hint_rail2]]

    def self.story
      $game_variables[391].to_i
    end

    # Whether a channel (a variable id) or a catwalk gap (a switch id) is frozen.
    def self.frozen?(id)
      RAILS[id] ? ($game_switches[id] ? true : false) : $game_variables[id].to_i >= 1
    end

    # The step the assist points at, [id, hint], or nil while nothing here waits.
    def self.step
      if story == 20
        s = CHAIN.find { |id, _key| !frozen?(id) }
        return s ? s : [nil, :rbb_glass_hint_door]
      end
      return nil if story < 23 || !$game_switches[957]
      RAIL_CHAIN.find { |id, _key| !frozen?(id) }
    end

    # The assisted line: fetch Glaceon, ride the west elevator with it, or freeze the step's channel or gap.
    def self.hint
      s = step
      return nil unless s
      return :rbb_glass_hint_fetch if story == 20 && s[0] && !$game_switches[946]
      return :rbb_glass_hint_elevator if RAILS[s[0]] && !($game_switches[946] && $game_switches[964])
      s[1]
    end

    # True with the assist while a channel or gap is the step's own, or the next the glass blocks' plan freezes.
    def self.next?(id)
      return true if PokeAccess::RebornGlassBlocks.next_channel == id
      s = PokeAccess::Puzzles.assist? ? step : nil
      !s.nil? && s[0] == id
    end

    # A channel's name: frozen, molten, or with the assist the next to freeze.
    def self.channel_label(id)
      return :rbb_glass_channel_frozen if frozen?(id)
      next?(id) ? :rbb_glass_channel_next : :rbb_glass_channel_molten
    end

    # A catwalk gap's name: frozen, overhead while on the lower level (switch 410), molten, or with the assist the next.
    def self.rail_label(id)
      return :rbb_glass_rail_frozen if frozen?(id)
      return :rbb_glass_rail_above if $game_switches[410]
      next?(id) ? :rbb_glass_rail_next : :rbb_glass_rail_molten
    end

    # Done once the glass is cleared away (switch 953) or, after the door's battle, both gaps towards the way out freeze.
    def self.solved?
      $game_switches[953] || (story >= 21 && frozen?(941) && frozen?(943))
    end
  end
end

PokeAccess::Game.define("reborn") do
  glass = PokeAccess::RebornGlassPaths
  mechanic(:state, 732, :part => :glaceon_paths) do
    auto
    glass::CHANNELS.each { |id, evs| name evs, lambda { |_ev| glass.channel_label(id) }, :grouped => true }
    glass::RAILS.each { |id, evs| name evs, lambda { |_ev| glass.rail_label(id) }, :grouped => true }
    watch :switch => 946, :label => :rbb_glass_glaceon, :on => :rbb_glass_glaceon_follows,
          :off => :rbb_glass_glaceon_stays
    arrival_hint lambda { glass.story >= 20 && glass.story < 45 && !glass.solved? ? :rbb_glass_rule : nil }
    active { PokeAccess::Puzzles.assist? && !glass.hint.nil? }
    hint lambda { glass.hint }
    solved(nil, :quiet => true) { glass.solved? }
  end
end
