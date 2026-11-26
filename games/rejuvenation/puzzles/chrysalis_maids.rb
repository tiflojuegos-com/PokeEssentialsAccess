# Chrysalis Courtyard and Manor (maps 390, 391 and 392), the servant's trial: the servant on the sofa (map 392, event
# 54) gives it (switch 994) and three maids drawn as any servant wait to be beaten, each adding 1 to variable 363. At 4
# the servant opens the manor's doors (switch 974).
module PokeAccess
  module RejuvMaids
    # Map => maid event => the self switch that marks her beaten.
    MAIDS = { 390 => { 42 => "A" }, 391 => { 53 => "B", 54 => "A" } }

    # How many maids are beaten, by their self switches (the hatch's panel sets variable 363 to 5).
    def self.beaten
      MAIDS.inject(0) do |n, (map, maids)|
        n + maids.count { |id, letter| $game_self_switches[[map, id, letter]] }
      end
    end

    # True while the trial is given and the doors are still shut.
    def self.open?
      $game_switches[994] && !$game_switches[974]
    end

    # The self switch that marks this map's maid beaten, or nil for any other event.
    def self.letter(ev)
      (MAIDS[$game_map.map_id] || {})[ev.id]
    end

    # True for a maid of this map not yet beaten, while the trial is open.
    def self.waiting?(ev)
      l = letter(ev)
      !l.nil? && open? && !$game_self_switches[[$game_map.map_id, ev.id, l]]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  maids = PokeAccess::RejuvMaids
  mechanic(:state, [390, 391, 392], :part => :maids) do
    auto
    name lambda { |ev| !maids.letter(ev).nil? }, lambda { |ev| maids.waiting?(ev) ? :rje_maids_maid : nil }, :assist => true
    count :rje_maids_beaten, :value => lambda { maids.beaten }, :of => 3, :hide_zero => true
    phase(lambda { maids.open? }, :quiet => true, :hint => :rje_maids_hint)
    solved(nil, :quiet => true) { $game_switches[974] }
  end
end
