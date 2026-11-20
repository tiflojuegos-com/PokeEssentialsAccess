# The rooms crossed with Dielebi, after the League: Ofiuchia (maps 446 and 574 to 582), Tauronordia (584 to 587) and Cansiria
# (569 to 572). A bell on a wall tile, an action event with no sprite whose page asks for Dielebi in the party, takes the
# player to the room's other version: a map of the same shape and name, with another floor and music, where switch 997
# stays on. Holes, event-touch tiles with no sprite, drop the player to the floor below. Bells and holes are drawn, so they
# are named, and the version is said on arriving and by the info key once Dielebi is in the party, or while the player is in
# its version. With the assist, the bells of the way out, the ones
# that land on a hole and the trees that leave a hole once cut are told apart.
module PokeAccess
  module XenoDielebi
    SIDE = 997
    BELLS = { 446 => [13, 14], 574 => [1, 2], 575 => [15, 16, 17, 18], 576 => [7, 8], 577 => [4], 578 => [2],
              579 => [18, 19, 20, 21], 580 => [1, 2, 3], 581 => [22, 23, 24, 26], 582 => [1, 2, 3, 4, 5, 7], 584 => [1],
              585 => [2, 3, 4, 5, 6, 7, 8, 9, 10], 586 => [1, 2, 3], 587 => [2], 569 => [1, 2, 3, 4, 5, 6],
              570 => [1, 5, 6, 7, 9], 571 => [7, 8, 9, 10, 11, 12, 13], 572 => [1, 2, 3, 4, 5, 6] }
    HOLES = { 575 => [6, 7, 8, 9], 576 => [2, 3, 4, 5, 6], 579 => (22..28).to_a, 580 => (4..9).to_a,
              581 => [14, 15, 16, 17, 18, 19, 20, 21, 25], 586 => (5..20).to_a, 570 => [8], 571 => (14..33).to_a,
              572 => (10..32).to_a }
    WAY = { 446 => [13], 574 => [2], 575 => [16, 18], 576 => [7], 579 => [18, 19, 21], 580 => [1, 3],
            581 => [22, 23, 24, 26], 582 => [1, 2, 3, 5], 585 => [3, 6, 9, 10], 586 => [1, 2, 3], 587 => [2],
            569 => [2, 5], 570 => [1, 5], 571 => [8, 10], 572 => [1, 2, 6] }
    ONTO_HOLE = { 575 => [15, 17], 579 => [20], 580 => [2], 582 => [4], 585 => [2, 4, 7, 8], 571 => [7, 9, 11],
                  572 => [4], 569 => [6] }
    HOLE_TREES = { 575 => [3, 10], 581 => [3, 5, 10, 12, 13] }
    FALLS = { 577 => [[575, 579, 581], [9, 10]], 578 => [[576, 580], [9, 10]], 584 => [[586], [13, 6]],
              569 => [[571], [14, 25]], 570 => [[572], [14, 23]] }
    MAPS = [446, 574, 575, 576, 577, 578, 579, 580, 581, 582, 584, 585, 586, 587, 569, 570, 571, 572]

    # The ids of one of the tables above for the map the player is on.
    def self.on_map(table)
      table[($game_map.map_id rescue 0)] || []
    end

    # A bell's name; with the assist, whether it is on the way out or lands on a hole.
    def self.bell_label(ev)
      return :xv_dielebi_bell unless PokeAccess::Puzzles.assist?
      return :xv_dielebi_bell_way if on_map(WAY).include?(ev.id)
      on_map(ONTO_HOLE).include?(ev.id) ? :xv_dielebi_bell_hole : :xv_dielebi_bell
    end

    # The version of the room the player is in, once Dielebi can ring the bells; nil before.
    def self.side_line
      return :xv_dielebi_side_other if $game_switches[SIDE]
      dielebi = (Kernel.send(:pbHasSpecies?, :DIELEBI) rescue false)
      dielebi ? :xv_dielebi_side_normal : nil
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  dielebi = PokeAccess::XenoDielebi
  dielebi::MAPS.each do |map|
    mechanic(:state, map) do
      auto
      name dielebi::BELLS[map], lambda { |ev| dielebi.bell_label(ev) }
      name dielebi::HOLES[map], :xv_dielebi_hole, :grouped => true if dielebi::HOLES[map]
      name dielebi::HOLE_TREES[map], :xv_dielebi_tree_hole, :assist => true if dielebi::HOLE_TREES[map]
      arrival_hint lambda { dielebi.side_line }
      active { !dielebi.side_line.nil? }
      fall = dielebi::FALLS[map]
      sent_back :xv_dielebi_fell, :maps => fall[0], :to => fall[1] if fall
    end
  end
end
