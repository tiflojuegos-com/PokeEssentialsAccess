# The Lonardo Crypt of case six (maps 288 to 291). Hall (288): switch EV15 toggles the three rocks of row 18 (EV16 to
# EV18). Vases (290): the red, green and violet ones (switches 102 to 104) are pushed into holes on 289, checked by EV5
# (106 to 108). Deep floor (291): switches II (EV12) and III (EV14) take rocks away; the rock of III (EV15) has to stay.
module PokeAccess
  module AshenCrypt
    HALL = 288
    HOLES = 289
    VASES = 290
    DEEP = 291
    # The vases of map 290, named by their colour.
    COLOURS = { 2 => :afa_vase_red, 10 => :afa_vase_orange, 11 => :afa_vase_yellow, 12 => :afa_vase_green,
                13 => :afa_vase_blue, 14 => :afa_vase_indigo, 15 => :afa_vase_violet }
    # The vases the riddles name, by the switch each sets as it is taken.
    RIGHT = { 2 => 102, 12 => 103, 15 => 104 }
    # The vases of map 289 in EV5's order: event, name, the switch that brings it, the one its hole sets, and the hole.
    PUSHES = [[6, :afa_vase_red, 102, 106, [2, 4]], [7, :afa_vase_green, 103, 107, [10, 9]],
              [8, :afa_vase_violet, 104, 108, [19, 4]]]
    # The ghosts on single tiles of each map.
    GHOSTS = { HALL => [25, 26, 27, 28], VASES => [17], DEEP => [24, 25, 26] }
    HALL_SWITCH = 15
    HALL_ROCKS = [16, 17, 18]
    DEEP_SWITCHES = [10, 12, 14]
    DEEP_ROCKS = [11, 13, 15]
    # Map 291's rock the slide in front of the way out stops on, and the switch that takes it away.
    STOPPER = 15
    STOPPER_SWITCH = 14
    DEEP_EXIT = 2

    # Whether a game switch is on.
    def self.on?(id); $game_switches[id] ? true : false; end

    # Whether a rock of a map has been taken away: its self switch A.
    def self.gone?(map, rock); $game_self_switches[[map, rock, "A"]] ? true : false; end

    # The first vase of map 289 still out of its hole, nil once all three are in.
    def self.next_push; PUSHES.find { |push| !on?(push[3]) }; end

    # Whether every vase the riddles name has been taken.
    def self.vases_taken?; RIGHT.values.all? { |id| on?(id) }; end
  end
end

PokeAccess::Game.define("ashenfrost") do
  crypt = PokeAccess::AshenCrypt
  assist = lambda { PokeAccess::Puzzles.assist? }
  crypt::GHOSTS.each do |map, ghosts|
    mechanic(:state, map, :part => :afa_ghosts) do
      auto
      avoid ghosts, :assist => true
    end
  end

  mechanic(:state, crypt::HALL, :part => :afa_rocks) do
    auto
    name crypt::HALL_SWITCH, :afa_crypt_switch
    name crypt::HALL_ROCKS, :afa_crypt_rock, :grouped => true
    phase lambda { assist.call && !crypt.gone?(crypt::HALL, crypt::HALL_ROCKS[0]) },
          :hint => :afa_hall_switch_hint, :hidden => right_way(crypt::HALL_SWITCH)
  end

  mechanic(:state, crypt::VASES, :part => :afa_vases) do
    auto
    crypt::COLOURS.each { |id, label| name id, label }
    crypt::RIGHT.each { |id, switch| right_choice id, :takes => { :switch => switch } }
    hide crypt::COLOURS.keys - crypt::RIGHT.keys, :assist => true
    phase lambda { assist.call && !crypt.vases_taken? }, :hint => :afa_vases_hint
    solved(nil, :quiet => true) { crypt.vases_taken? }
  end

  mechanic(:state, crypt::HOLES, :part => :afa_holes) do
    auto
    crypt::PUSHES.each do |push|
      name push[0], push[1]
      spot :at => push[4], :label => :afa_hole, :when => lambda { !crypt.on?(push[3]) }
      phase lambda { assist.call && crypt.next_push == push && crypt.on?(push[2]) },
            :hint => lambda { [:afa_hole_hint, { :vase => PokeAccess::I18n.t(push[1]) }] },
            :track => { :event => push[0], :label => push[1],
                        :goal => [push[4][0], push[4][1], push[4][0], push[4][1]], :goal_label => :afa_hole }
    end
    solved(nil, :quiet => true) { crypt.next_push.nil? }
  end

  mechanic(:state, crypt::DEEP, :part => :afa_rocks) do
    auto
    crypt::DEEP_ROCKS.each { |rock| watch :self => [rock, "A"], :quiet => true }
    controls
    obstacle({ :events => crypt::DEEP_ROCKS }, :label => :afa_crypt_rock)
    name crypt::DEEP_SWITCHES, :afa_crypt_switch
    name crypt::DEEP_ROCKS, :afa_crypt_rock
    phase lambda { assist.call && crypt.gone?(crypt::DEEP, crypt::STOPPER) },
          :hint => :afa_deep_stopper_hint, :hidden => right_way(crypt::STOPPER_SWITCH)
    solved(nil, :quiet => true) { crypt.gone?(crypt::DEEP, crypt::DEEP_EXIT) }
  end
end
