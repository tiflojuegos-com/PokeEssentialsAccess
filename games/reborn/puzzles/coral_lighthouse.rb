# Coral Ward's lighthouses, Popplio (maps 526, 608, 609, 610): the shore door at (26, 5) of 526 takes the Coral Key
# alone, which lies in 609 behind a rusted door. Dive at (26, 13) of 526, cross 608 to the hole (26, 19), come up at
# 610's pool (33, 15), climb the ladder (34, 12) to the key (52, 10); (16, 16) then starts the battle (switch 798).
module PokeAccess
  module RebornCoralLighthouse
    SHORE = 526
    INSIDE = 609
    FLOOR = 610
    DOOR = 54
    RUSTED = 1
    POPPLIO = 4
    DONE = 798

    # True while the Popplio still waits for help.
    def self.waiting?
      !$game_switches[DONE]
    end

    # True while the shore door is still locked.
    def self.locked?
      !$game_self_switches[[SHORE, DOOR, "A"]]
    end
  end
end

PokeAccess::Game.define("reborn") do
  cl = PokeAccess::RebornCoralLighthouse
  mechanic(:state, cl::SHORE, :part => :lighthouse) do
    auto
    name cl::DOOR, lambda { |_ev| cl.locked? ? :rbj_coral_door : nil }, :when => lambda { |_ev| cl.locked? }
    spot(:at => [26, 15], :label => :rbj_coral_dive, :assist => true, :onto => true,
         :when => lambda { cl.waiting? && cl.locked? })
    hint :rbj_coral_hint
    active { PokeAccess::Puzzles.assist? && cl.waiting? }
  end

  mechanic(:state, cl::INSIDE, :part => :lighthouse) do
    auto
    name cl::RUSTED, :rbj_coral_rusted
    hint :rbj_coral_hint_inside
    active { PokeAccess::Puzzles.assist? && cl.waiting? }
  end

  mechanic(:state, cl::FLOOR, :part => :popplio) do
    auto
    name cl::POPPLIO, :rbj_coral_popplio, :when => lambda { |_ev| cl.waiting? }
    solved(nil, :quiet => true) { !cl.waiting? }
  end
end
