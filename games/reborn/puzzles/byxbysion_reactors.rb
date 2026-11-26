# Byxbysion Wasteland (map 209): five reactors, each worked by the action button, turn switches 185 to 189 on and off
# with a glow and no text. A parallel process sets 190 once all five are on, and the locked door at (75, 49) then leads
# into the grotto. Each reactor says whether it is lit; with the assist, how many are and where the door is.
module PokeAccess
  module RebornReactors
    MAP = 209
    REACTORS = { 149 => 185, 150 => 186, 155 => 187, 164 => 188, 172 => 189 }
    DOOR = 183
    OPEN = 190

    # The name of a reactor, lit or not.
    def self.label(ev)
      $game_switches[REACTORS[ev.id]] ? :rbd_bx_reactor_lit : :rbd_bx_reactor_dark
    end
  end
end

PokeAccess::Game.define("reborn") do
  bx = PokeAccess::RebornReactors
  mechanic(:state, bx::MAP, :part => :reactors) do
    auto
    not_control bx::REACTORS.keys
    name bx::REACTORS.keys, lambda { |ev| bx.label(ev) }
    bx::REACTORS.values.each do |switch|
      watch :switch => switch, :label => :rbd_bx_reactor, :on => :rbd_bx_lit, :off => :rbd_bx_dark
    end
    count :rbd_bx_count, :switches => bx::REACTORS.values, :assist => true
    spot :event => bx::DOOR, :label => :rbd_bx_door, :assist => true, :when => lambda { !$game_switches[bx::OPEN] }
    hint :rbd_bx_hint
    info { nil }
    active { PokeAccess::Puzzles.assist? && !$game_switches[bx::OPEN] }
    solved(nil, :quiet => true) { $game_switches[bx::OPEN] }
  end
end
