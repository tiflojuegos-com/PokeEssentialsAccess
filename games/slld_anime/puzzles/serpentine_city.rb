# Serpentine City's two side quests (map 15). The Headbutt Man's Pupool (event 25) keeps the small house's door; with
# the Rare Bone of Serpentine Garden (map 149, 24,21) in the bag it runs after the bone (switch 436). Then Lavenseed
# (switch 440) catches the Pupool that runs about (event 65): each press facing it adds one to variable 365, at five it
# stops (page 4) and the sixth makes it follow (switch 441). The Birdkeeper (event 83) asks for a Flying-type Pokemon,
# and Budcheep (switch 445) flies over the roofs: a press facing a Paracaw (events 88 to 95, common event 23) moves it a
# tile away, and on its roof's edge it flies off and adds one to variable 369; eight (switch 446) ends it. The counts
# and each Paracaw's pushes come with the assist alone. The tired Pupool is no control for auto, which would call the
# sixth press a mechanism worked.
module PokeAccess
  module SlldParacaw
    MAP = 15
    # Each Paracaw's roof edges: the columns and the rows that send it off (common event 23).
    EDGES = { 88 => [[20, 26], [24, 28]], 89 => [[14, 20], [18, 22]], 90 => [[14, 20], [18, 22]],
              91 => [[39, 47], [20, 24]], 92 => [[30, 36], [12, 16]], 93 => [[41, 49], [8, 13]],
              94 => [[41, 49], [8, 13]], 95 => [[15, 21], [4, 8]] }
    DIRS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }

    # The fewest presses that take Paracaw id from (x, y) to an edge of its roof, and the ways each of them pushes it.
    def self.pushes(id, x, y)
      cols, rows = EDGES[id]
      ways = cols.map { |e| [(e - x).abs, e > x ? 6 : 4] } + rows.map { |e| [(e - y).abs, e > y ? 2 : 8] }
      n = ways.map { |w| w[0] }.min
      [n, ways.select { |w| w[0] == n }.map { |w| w[1] }.uniq]
    end

    # With the assist, a Paracaw named by its pushes from where it stands; nil otherwise, for its own name.
    def self.label(ev)
      return nil unless PokeAccess::Puzzles.assist? && EDGES[ev.id]
      n, dirs = pushes(ev.id, ev.x, ev.y)
      t = PokeAccess::I18n
      way = dirs.map { |d| t.t(DIRS[d]) }.inject { |a, b| t.t(:fx_slld_paracaw_or, :a => a, :b => b) }
      [:fx_slld_paracaw_push, { :n => n, :dirs => way }]
    end

    # With the assist, the facings a press pushes Paracaw ev toward its roof's nearest edge from; nil otherwise.
    def self.sides(ev)
      return nil unless $game_map.map_id == MAP && EDGES[ev.id] && PokeAccess::Puzzles.assist? && perched?(ev.id)
      pushes(ev.id, ev.x, ev.y)[1]
    end

    # True while Paracaw id sits on its roof during the quest.
    def self.perched?(id)
      $game_switches[445] && !$game_self_switches[[MAP, id, "A"]] ? true : false
    end
  end
end

PokeAccess::Game.define("slld_anime") do
  paracaw = PokeAccess::SlldParacaw
  choose = lambda { |species| [:puzzle_answer, { :a => PokeAccess::Data.species_name(species).to_s }] }
  act_sides { |ev| paracaw.sides(ev) }
  mechanic(:state, 15, :part => :pupool) do
    auto
    not_control 65
    on_reach 25, { :text => /leave that house alone/ }, :fx_slld_pupool_bone, :assist => true
    count :fx_slld_pupool_presses, :value => lambda { $game_variables[365].to_i + ($game_switches[441] ? 1 : 0) }, :of => 6,
          :assist => true, :hide_zero => true
    active { $game_switches[440] && !$game_switches[441] }
    solved(nil, :quiet => true) { $game_switches[441] }
    hint :fx_slld_pupool_hint
  end
  mechanic(:state, 15, :part => :paracaw) do
    auto
    on_reach 83, { :text => /without a type disadvantage/ }, lambda { |_ev| choose.call(:BUDCHEEP) }, :assist => true
    name(/\AParacaw \d\z/, lambda { |ev| paracaw.label(ev) }, :when => lambda { |ev| paracaw.perched?(ev.id) })
    count :fx_slld_paracaws, :var => 369, :of => 8, :assist => true, :hide_zero => true
    active { $game_switches[445] && !$game_switches[446] }
    solved(nil, :quiet => true) { $game_switches[446] }
    hint :fx_slld_paracaw_hint
  end
end
