# Mauville Gym, in two rooms: floor pads drawn with a tile each turn on a switch that takes down rows of electric
# barriers for good. The first room (map 183) needs both its pads, at (5,29) for switch 152 and (13,29) for 151; the
# second (map 184) needs its three in turn, each opening the way to the next: (14,43) for 153, (5,38) for 154 and
# (13,34) for 155, then Wattson. Checked by a search over each room's flags; the core says what each pad opens.
module PokeAccess
  module EmMauville
    FIRST = 183
    SECOND = 184
    ORDER = [[153, [14, 43]], [154, [5, 38]], [155, [13, 34]]]

    # The assist's line in the second room: where the next pad to step on lies.
    def self.next_pad
      sw, (x, y) = ORDER.find { |s, _| !$game_switches[s] }
      return nil unless sw
      [:em_mauville_next, { :place => PokeAccess::EmPuzzles.place(x, y) }]
    end
  end
end

PokeAccess::Game.define("emerald") do
  gym = PokeAccess::EmMauville
  mechanic(:state, gym::FIRST) do
    auto
    watch :switch => 151, :quiet => true
    watch :switch => 152, :quiet => true
    controls
    obstacle(/Lightning/i, :label => :em_mauville_barrier)
    name [13, 14], :em_mauville_pad, :when => lambda { |ev| !$game_switches[ev.id == 13 ? 151 : 152] }
    arrival_hint :em_mauville_rule
    hint :em_mauville_first_hint
    solved { $game_switches[151] && $game_switches[152] }
  end

  mechanic(:state, gym::SECOND) do
    auto
    gym::ORDER.each { |sw, _| watch :switch => sw, :quiet => true }
    controls
    obstacle(/Lightning/i, :label => :em_mauville_barrier)
    name [1, 10, 22], :em_mauville_pad, :when => lambda { |ev| !$game_switches[{ 1 => 153, 10 => 154, 22 => 155 }[ev.id]] }
    phase lambda { PokeAccess::Puzzles.assist? && gym.next_pad }, :quiet => true, :hint => lambda { gym.next_pad }
    solved { gym::ORDER.all? { |sw, _| $game_switches[sw] } }
  end
end
