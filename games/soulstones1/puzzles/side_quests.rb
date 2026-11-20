# Side quests that ask to find things on a map. Kakui Beach (map 149): six baby Staryu (events 2 to 7, variable 87 from
# 1 to 7) go back to the water only when touched facing down. Route 110 (map 234): the beached Wailord (event 2), pushed
# with Strength once Ken asks (its self switch A), goes back to the sea from (64, 58), seven tiles north. Stonecrest City
# (map 86): four sprite-less broken street lights (events 67 to 70, variable 41 from 1 to 5) recharged by an Electric
# type. The arcane wards of Vega City and its routes (variable 111 from 1 to 5), recharged by a Psychic type. Route 110's
# four trapped Lapras (events 6 to 9, variable 120 from 1 to 5) come free only faced from one side. Kakui Beach's eleven
# sprite-less clams (events 27 to 37) open with the flute lady's quest (variable 89 from 1 to 4): three hold a gem (events
# 27, 29 and 30), the rest a Clamperl. Planet Rasha Prime (map 494): five odd shrubs (events 4 to 8, variable 335 from 1
# to 6) give a sample to a Grass type.
module PokeAccess
  module SoulstonesQuests
    WARDS = { 183 => 51, 199 => 14, 203 => 1, 207 => 2 }
    # Lapras event => the side it is freed from.
    LAPRAS = { 6 => :ss1_lapras_from_south, 7 => :ss1_lapras_from_west, 8 => :ss1_lapras_from_east,
               9 => :ss1_lapras_from_south }
    GEM_CLAMS = [27, 29, 30]

    # True while variable var stands from 1 to last, the quest under way.
    def self.during?(var, last)
      (1..last).include?($game_variables[var].to_i)
    end

    # True while the Wailord is being pushed: asked for and not yet back in the sea.
    def self.wailord?
      $game_self_switches[[234, 2, "A"]] && !$game_self_switches[[234, 2, "B"]]
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  q = PokeAccess::SoulstonesQuests

  mechanic(:state, 149, :part => :staryu) do
    auto
    count :ss1_staryu, :value => lambda { [[$game_variables[87].to_i - 1, 0].max, 6].min }, :of => 6, :assist => true,
                       :hide_zero => true
    arrival_hint lambda { q.during?(87, 6) ? :ss1_staryu_rule : nil }, :once => true
    active { q.during?(87, 6) }
    solved(nil, :quiet => true) { $game_variables[87].to_i >= 7 }
  end

  mechanic(:state, 234, :part => :wailord) do
    auto
    phase lambda { q.wailord? }, :quiet => true, :hint => :ss1_wailord_hint,
          :track => { :event => 2, :label => :ss1_wailord, :goal => [64, 58, 64, 58], :goal_label => :ss1_wailord_sea }
    active { q.wailord? }
  end

  mechanic(:state, 86) do
    auto
    name 67..70, :ss1_street_light, :when => lambda { |_ev| q.during?(41, 4) }
    count :ss1_street_lights, :value => lambda { [[$game_variables[41].to_i - 1, 0].max, 4].min }, :of => 4,
                              :assist => true, :hide_zero => true
    solved(nil, :quiet => true) { $game_variables[41].to_i >= 5 }
  end

  mechanic(:state, 234, :part => :lapras) do
    auto
    name q::LAPRAS.keys, lambda { |ev| PokeAccess::Puzzles.assist? ? q::LAPRAS[ev.id] : nil },
         :when => lambda { |_ev| q.during?(120, 5) }
    count :ss1_lapras_freed, :value => lambda { [[$game_variables[120].to_i - 1, 0].max, 4].min }, :of => 4,
                             :assist => true, :hide_zero => true
    solved(nil, :quiet => true) { $game_variables[120].to_i >= 6 }
  end

  mechanic(:state, 149, :part => :clams) do
    auto
    name 27..37, lambda { |ev|
      next :ss1_clam unless PokeAccess::Puzzles.assist? && q.during?(89, 3)
      q::GEM_CLAMS.include?(ev.id) ? :ss1_clam_gem : :ss1_clam_pokemon
    }, :when => lambda { |ev| !$game_self_switches[[149, ev.id, "A"]] }
    count :ss1_clam_gems, :value => lambda { [[$game_variables[89].to_i - 1, 0].max, 3].min }, :of => 3,
                          :assist => true, :hide_zero => true
    solved(nil, :quiet => true) { $game_variables[89].to_i >= 4 }
  end

  mechanic(:state, 494) do
    auto
    name 4..8, :ss1_sample_shrub, :when => lambda { |ev| q.during?(335, 5) && !$game_self_switches[[494, ev.id, "A"]] }
    count :ss1_samples, :value => lambda { [[$game_variables[335].to_i - 1, 0].max, 5].min }, :of => 5, :assist => true,
                        :hide_zero => true
    solved(nil, :quiet => true) { $game_variables[335].to_i >= 6 }
  end

  q::WARDS.each do |map, ev|
    mechanic(:state, map, :part => :wards) do
      auto
      name ev, :ss1_arcane_ward, :when => lambda { |_ev| q.during?(111, 4) }
      count :ss1_arcane_wards, :value => lambda { [[$game_variables[111].to_i - 1, 0].max, 4].min }, :of => 4,
                               :assist => true, :hide_zero => true
      solved(nil, :quiet => true) { $game_variables[111].to_i >= 5 }
    end
  end
end
