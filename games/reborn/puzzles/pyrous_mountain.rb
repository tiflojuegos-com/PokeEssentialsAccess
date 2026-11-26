# Pyrous Mountain: each floor with a lava lake has two maps, the full one loaded while its switch is on (1F map 34 with
# 175, B1F 199 with 174, 2F 202 with 176, 3F 204 with 177). A glowing rock drains the floor above and fills another:
# 1F's (event 3) needs 176, B1F's (4) 175, B2F's (5) 174, 2F's (7) 177.
module PokeAccess
  module RebornPyrous
    ROCKS = { 33 => 3, 34 => 3, 35 => 4, 199 => 4, 200 => 5, 201 => 7, 202 => 7 }
    GLOWING = "rocksmash3b"
    MAPS = [33, 34, 35, 199, 200, 201, 202, 203, 204]

    # True when switch s is on.
    def self.on?(s); $game_switches[s] ? true : false; end

    # A rock's name while its page draws it glowing, else none.
    def self.rock_label(ev)
      ev.character_name.to_s == GLOWING ? :rba_pm_glowing_rock : nil
    end

    # True once no lake cuts the way to the top.
    def self.drained?; !on?(175) && !on?(176) && !on?(177); end

    # With the assist, the next rock to break, by the lakes as they stand; nil once they are drained.
    def self.hint
      return :rba_pm_hint_b1 if on?(175)
      return :rba_pm_hint_1f if on?(176)
      on?(177) ? :rba_pm_hint_2f : nil
    end
  end
end

PokeAccess::Game.define("reborn") do
  pyrous = PokeAccess::RebornPyrous
  pyrous::MAPS.each do |map|
    rock = pyrous::ROCKS[map]
    mechanic(:state, map) do
      auto
      name rock, lambda { |ev| pyrous.rock_label(ev) } if rock
      hint lambda { pyrous.hint }
      active { !pyrous.drained? }
      solved { pyrous.drained? }
    end
  end
end
