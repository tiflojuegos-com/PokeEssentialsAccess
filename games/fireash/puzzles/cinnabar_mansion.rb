# Cinnabar's Pokemon Mansion (maps 189 to 192): the way to the Person on B1F who sets switch 59 goes 1F stairs up (event 2),
# 2F stairs up (1), 3F stairs down (3), the hole of 2F (5) and 1F stairs down (4). Each floor's stairs lead to separate areas.
# TOWARDS holds those, by map; the assist alone tells them apart.
module PokeAccess
  module FireAshMansion
    TOWARDS = { 189 => [2, 4], 190 => [1, 5], 191 => [3] }
    NAMES = { 189 => { 2 => :fa_stairs_2f, 4 => :fa_stairs_b1f },
              190 => { 1 => :fa_stairs_3f, 2 => :fa_stairs_3f, 3 => :fa_stairs_3f, 4 => :fa_stairs_1f, 5 => :fa_hole },
              191 => { 1 => :fa_stairs_2f, 2 => :fa_stairs_2f, 3 => :fa_stairs_2f },
              192 => { 2 => :fa_stairs_1f } }

    # The label of a stairs or hole event on the current map; with the assist, whether it nears the basement.
    def self.label(ev)
      map = $game_map.map_id
      name = PokeAccess::I18n.t(NAMES[map][ev.id])
      near = PokeAccess::Puzzles.assist? && !$game_switches[59] && (TOWARDS[map] || []).include?(ev.id)
      near ? PokeAccess::I18n.t(:fa_mansion_towards, :label => name) : name
    end
  end
end

PokeAccess::Game.define("fireash") do
  towards_label = lambda { |ev| PokeAccess::FireAshMansion.label(ev) }
  mechanic(:state, 189) do
    auto
    name [2, 4], towards_label
    sent_back :fa_mansion_fell, :maps => [190], :to => [34, 31]
    solved { $game_switches[59] }
  end
  mechanic(:state, 190) do
    auto
    name 1..5, towards_label
    arrival_hint :fa_mansion_rule
    solved { $game_switches[59] }
  end
  mechanic(:state, 191) do
    auto
    name 1..3, towards_label
    arrival_hint :fa_mansion_rule
    solved { $game_switches[59] }
  end
  mechanic(:state, 192) do
    auto
    name 2, towards_label
    solved { $game_switches[59] }
  end
end
