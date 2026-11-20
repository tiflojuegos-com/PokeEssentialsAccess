# Shadow HQ: the three gem bases (maps 111 and 113, var 29 counts the gems set; two open map 111's door to the Phantom Path,
# three map 113's door out), the Phantom Path (map 112), the room of boxes with the Nox card chest (map 115) and the room of
# floor teleports with the laser and the Nova card (map 118).
module PokeAccess
  module DHBoxes
    HOME = { 49 => [72, 10], 50 => [73, 9], 51 => [74, 10], 52 => [75, 13], 53 => [73, 11], 55 => [70, 14], 56 => [77, 7],
             57 => [78, 7], 58 => [78, 6], 59 => [69, 7], 60 => [68, 6], 61 => [72, 12] }

    # The hint: the four pushes, which hold only from the boxes' starting places, led by how to put them back when one has
    # been moved (the map's moved events are cleared on entering it).
    def self.hint
      moved = HOME.any? do |id, xy|
        ev = $game_map.events[id]
        ev && [ev.x, ev.y] != xy
      end
      t = PokeAccess::I18n
      PokeAccess.sentences(moved ? [t.t(:dh_pz_boxes_reset), t.t(:dh_pz_boxes_hint)] : [t.t(:dh_pz_boxes_hint)])
    end
  end

  module DHGems
    GEMS = [[:RUBY, 111, 18, :ruby], [:SAPPHIRE, 111, 19, :sapphire], [:EMERALD, 113, 22, :emerald]]
    OPENS = { 111 => :dh_pz_gems_open_phantom, 113 => :dh_pz_gems_open_exit }

    # True when the gem's base holds it.
    def self.placed?(gem)
      $game_self_switches[[gem[1], gem[2], "A"]] ? true : false
    end

    # True when the bag holds the gem.
    def self.held?(gem)
      ($bag.has?(gem[0]) rescue false) ? true : false
    end

    # A base's name: with the assist, the gem it takes.
    def self.base(map, ev)
      gem = GEMS.find { |g| g[1] == map && g[2] == ev.id }
      PokeAccess::Puzzles.assist? && gem ? "dh_pz_base_#{gem[3]}".to_sym : :dh_pz_gem_base
    end

    # The hint: for each gem not set, to set it or who has it; then what the count opens on map.
    def self.hint(map)
      t = PokeAccess::I18n
      parts = GEMS.reject { |g| placed?(g) }.map do |g|
        held?(g) ? t.t(:dh_pz_gem_have, :gem => t.t("dh_pz_gem_#{g[3]}".to_sym)) : t.t("dh_pz_gem_#{g[3]}_from".to_sym)
      end
      parts.push(t.t(OPENS[map]))
      PokeAccess.sentences(parts)
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  { 111 => 2, 113 => 3 }.each do |map, need|
    mechanic(:state, map) do
      auto
      name PokeAccess::DHGems::GEMS.select { |g| g[1] == map }.map { |g| g[2] }, lambda { |ev| PokeAccess::DHGems.base(map, ev) }
      watch :var => 29, :number => true, :label => :dh_pz_gems_placed
      solved { $game_variables[29] >= need }
      hint lambda { PokeAccess::DHGems.hint(map) }
    end
  end

  mechanic(:state, 112) do
    auto
    sent_back :dh_pz_phantom_fell, :to => [9, 17]
    solved { $game_switches[215] }
    arrival_hint :dh_pz_phantom_rule, :once => true
  end

  mechanic(:state, 115) do
    auto
    room = at(66, 79, 7, 15)
    phase lambda { room.call && !$game_self_switches[[115, 68, "A"]] }, :title => :dh_pz_boxes_rule, :hint => lambda { PokeAccess::DHBoxes.hint }
  end

  mechanic(:state, 118) do
    auto
    sent_back :dh_pz_wallclock, :events => [41, 42, 43, 44, 45, 46, 49, 50, 51, 52, 53, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65,
                                          66, 67, 68, 69, 70, 71, 72, 73, 74]
    name 35, :dh_pz_laser_panel
    name 37, :dh_pz_laser, :when => lambda { |_ev| !$game_switches[172] }
    phase lambda { !$game_switches[172] }, :title => :dh_pz_laser_on, :quiet => true, :hint => :dh_pz_tele_hint
  end
end
