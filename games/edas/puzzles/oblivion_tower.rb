# Edas' Tower of Oblivion, climbed in the Amber chapter after the true ending. Floors 0, 1 and 7 (maps 133, 134 and 90) keep
# an order in a variable (77, or 85 on floor 7): the right step moves it on, a wrong one sets it back, and the whole order
# wakes the way up. The torches that mark the steps of floors 0 and 7 show only to the Eye of Truth and far from the steps,
# so their count is the assist's. Floor 2 (map 135) wants its four ghosts beaten in turn, floors 3 and 6 (maps 136 and 139)
# wake their keeper only to the Eye of Truth, floors 4 and 5 (maps 137 and 138) follow a ghost Meowth by tracks the eye
# shows, and floor 8 (map 92) lays the way to Choi's painting with the fights inside the other four. What only the eye
# shows is named only while it shows it, the eye up and the thing within its reach (World::Lens.reaches?).
module PokeAccess
  module EdasTower
    ORDERS = [{ :map => 133, :var => 77, :base => 0, :steps => [6, 7, 14, 4], :up => 9 },
              { :map => 134, :var => 77, :base => 10, :steps => [23, 63, 24, 62], :up => 61 },
              { :map => 135, :var => 77, :base => 20, :steps => [7, 9, 5, 8], :up => 142 },
              { :map => 90, :var => 85, :base => 0, :steps => [6, 8, 9, 10] }]
    TILES = { 14 => 1, 6 => 2, 4 => 3, 7 => 4 }
    CRYSTALS = { 23 => :dir_so, 63 => :dir_se, 24 => :dir_no, 62 => :dir_ne }
    WAYS = { 6 => :dir_n, 8 => :dir_o, 9 => :dir_e, 10 => :dir_s }
    TRAPS = [44, 45, 46, 47]
    GHOSTS = { 7 => 579, 9 => 707, 5 => 414, 8 => 292 }
    PICTURES = { 1 => 579, 2 => 707, 3 => 414, 4 => 292 }
    TORCHES = { 133 => { 1 => 1, 3 => 1, 5 => 2, 2 => 3 }, 90 => { 1 => 1, 3 => 1, 2 => 2 } }
    TRAILS = [{ :map => 137, :var => 83, :first => 0, :meowth => [109, 116, 121, 9], :up => 29 },
              { :map => 138, :var => 84, :first => 1, :meowth => [148, 154, 155], :up => 171 }]
    KEEPERS = { 136 => [40, 243], 139 => [70, 246] }
    GALLERY = 92
    PAINTINGS = [[7, 251, :edas_tower_painting_vivinne], [13, 253, :edas_tower_painting_lobrego],
                 [44, 252, :edas_tower_painting_praline], [55, 254, :edas_tower_painting_nihkil]]
    CHOI = 57
    CHOI_BEATEN = 90
    WORLDS = [146, 147, 148, 150]

    # The ordered floor on a map.
    def self.order(map)
      ORDERS.find { |f| f[:map] == map }
    end

    # How many steps of a floor's order stand right: its variable past where the floor starts, up to all of them.
    def self.done(floor)
      [[$game_variables[floor[:var]].to_i - floor[:base], 0].max, floor[:steps].length].min
    end

    # Whether a floor's whole order stands.
    def self.climbed?(floor)
      done(floor) == floor[:steps].length
    end

    # A step's name: the tile by its place from the west, the crystal by its corner and its light, the ghost by its
    # species, the edge by its side.
    def self.step_name(map, id)
      t = PokeAccess::I18n
      case map
      when 133 then t.t(:edas_tower_tile, :n => TILES[id])
      when 134
        lit = done(order(134)) > order(134)[:steps].index(id)
        t.t(lit ? :edas_tower_crystal_lit : :edas_tower_crystal_dark, :dir => t.t(CRYSTALS[id]))
      when 135 then species(GHOSTS[id])
      when 90 then t.t(:edas_tower_way, :dir => t.t(WAYS[id]))
      end
    end

    # A step's name in the lists: the crystals of floor 1 only while the eye shows them.
    def self.listed_step(map, ev)
      return nil if map == 134 && !PokeAccess::World::Lens.reaches?(ev)
      step_name(map, ev.id)
    end

    # The assist's line for step i of a floor: the piece it wants by name.
    def self.next_line(floor, i)
      PokeAccess::I18n.t(:edas_next, :what => step_name(floor[:map], floor[:steps][i]))
    end

    # A species' name as the game writes it.
    def self.species(id)
      PokeAccess::Data.species_name(id).to_s
    end

    # A wall torch of floor 0 or 7 while the eye shows it, lit or out by its floor's variable.
    def self.torch_name(map, ev)
      return nil unless PokeAccess::World::Lens.reaches?(ev)
      lit = $game_variables[order(map)[:var]].to_i >= TORCHES[map][ev.id]
      lit ? :edas_cata_torch_lit : :edas_cata_torch_out
    end

    # A picture of floor 2's north wall while the eye shows it, by the species it shows.
    def self.picture_name(ev)
      return nil unless PokeAccess::World::Lens.reaches?(ev)
      PokeAccess::I18n.t(:edas_tower_picture, :name => species(PICTURES[ev.id]))
    end

    # What a loose tile of floor 1 says as it sends the player back; with the assist, that the eye keeps it still.
    def self.trap_line
      hint = PokeAccess::Puzzles.assist? ? PokeAccess::I18n.t(:edas_tower_trap_hint) : nil
      PokeAccess.sentences([PokeAccess::I18n.t(:edas_tower_trap_back), hint])
    end

    # The assist's line once a floor is through: the crystal that climbs.
    def self.up_line
      PokeAccess::I18n.t(:edas_next, :what => PokeAccess::I18n.t(:edas_tower_up))
    end

    # How many Meowth of a floor's trail are caught; the last sets its variable to 10.
    def self.caught(trail)
      v = $game_variables[trail[:var]].to_i
      return trail[:meowth].length if v >= 10
      [[v - trail[:first], 0].max, trail[:meowth].length].min
    end

    # Whether the keeper of floor 3 or 6 has yet to show: not beaten (variable 77) and the scene's switch still off.
    def self.keeper_ahead?(map)
      value, scene = KEEPERS[map]
      $game_variables[77].to_i < value && !$game_switches[scene]
    end

    # The paintings whose fight is not won yet.
    def self.missing
      PAINTINGS.reject { |_id, switch, _label| $game_switches[switch] }
    end

    # The paintings completed, said as a count.
    def self.paintings_line
      PokeAccess::I18n.t(:puzzle_progress, :label => PokeAccess::I18n.t(:edas_tower_paintings),
                                           :n => PAINTINGS.length - missing.length, :of => PAINTINGS.length)
    end

    # The assist's line on floor 8: the paintings still to win, or Choi's once all four are.
    def self.gallery_hint
      left = missing.map { |_id, _switch, label| PokeAccess::I18n.t(label) }
      return PokeAccess::I18n.t(:edas_next, :what => PokeAccess::I18n.t(:edas_tower_painting_choi)) if left.empty?
      PokeAccess::I18n.t(:edas_tower_missing, :list => PokeAccess::Routes::Text.and_list(left), :n => left.length)
    end
  end
end

PokeAccess::Game.define("edas") do
  tower = PokeAccess::EdasTower
  shown = lambda { |ev| PokeAccess::World::Lens.reaches?(ev) }
  counts = { 133 => [:edas_tower_steps, true], 134 => [:edas_tower_crystals, :edas_tower_crystals_out],
             135 => [:edas_tower_ghosts, false], 90 => [:edas_tower_steps, true] }
  far_torches = [133, 90]
  rules = { 133 => :edas_tower_p0_rule, 134 => :edas_tower_p1_rule, 135 => :edas_tower_p2_rule, 90 => :edas_tower_p7_rule }
  tower::ORDERS.each do |floor|
    map = floor[:map]
    mechanic(:state, map) do
      auto
      if map == 135
        name tower::PICTURES.keys, lambda { |ev| tower.picture_name(ev) }, :when => shown
      else
        name floor[:steps], lambda { |ev| tower.listed_step(map, ev) },
             :when => lambda { |ev| map != 134 || shown.call(ev) }
      end
      if tower::TORCHES[map]
        name tower::TORCHES[map].keys, lambda { |ev| tower.torch_name(map, ev) }, :when => shown
      end
      label, reset = counts[map]
      count label, :value => lambda { tower.done(floor) }, :of => floor[:steps].length, :hide_zero => true, :reset => reset,
                   :assist => far_torches.include?(map)
      arrival_hint rules[map], :once => [134, 135].include?(map)
      solved { tower.climbed?(floor) }
      floor[:steps].each_with_index do |event, i|
        phase lambda { tower.done(floor) == i }, :hint => lambda { tower.next_line(floor, i) }, :hidden => right_way(event)
      end
      phase lambda { tower.climbed?(floor) }, :hint => lambda { tower.up_line }, :hidden => right_way(floor[:up]) if floor[:up]
      sent_back :edas_tower_center, :to => [32, 13], :events => floor[:steps] if map == 133
      sent_back :edas_tower_center, :to => [9, 10], :events => floor[:steps] if map == 90
      if map == 134
        sent_back lambda { tower.trap_line }, :to => [8, 22], :events => tower::TRAPS
        avoid tower::TRAPS, :assist => true
      end
      sent_back :edas_tower_ghosts_back, :maps => [134], :from => [8, 22], :to => [30, 57] if map == 135
    end
  end

  tower::TRAILS.each do |trail|
    mechanic(:state, trail[:map]) do
      auto
      name trail[:meowth], lambda { |ev| shown.call(ev) ? :edas_tower_meowth : nil }, :when => shown
      count :edas_tower_meowth_found, :value => lambda { tower.caught(trail) }, :of => trail[:meowth].length,
                                      :assist => true, :reset => false
      arrival_hint :edas_tower_trail_rule
      solved { tower.caught(trail) == trail[:meowth].length }
      trail[:meowth].each_with_index do |event, i|
        phase lambda { tower.caught(trail) == i }, :hint => :edas_tower_meowth_hint, :hidden => right_way(event)
      end
      phase lambda { tower.caught(trail) == trail[:meowth].length }, :hint => lambda { tower.up_line },
            :hidden => right_way(trail[:up])
    end
  end

  tower::KEEPERS.each_key do |map|
    mechanic(:state, map) do
      auto
      active { PokeAccess::Puzzles.assist? && tower.keeper_ahead?(map) }
      phase lambda { tower.keeper_ahead?(map) }, :hint => :edas_tower_keeper_hint
    end
  end

  mechanic(:state, tower::GALLERY) do
    auto
    tower::PAINTINGS.each { |id, _switch, label| name id, label }
    name tower::CHOI, :edas_tower_painting_choi
    count :edas_tower_paintings, :switches => tower::PAINTINGS.map { |_id, switch, _label| switch }, :announce => false,
                                 :reset => false
    sent_back lambda { tower.paintings_line }, :maps => tower::WORLDS
    arrival_hint :edas_tower_p8_rule, :once => true
    solved { $game_variables[77].to_i >= tower::CHOI_BEATEN }
    phase lambda { !tower.missing.empty? }, :hint => lambda { tower.gallery_hint }
    phase lambda { tower.missing.empty? }, :hint => lambda { tower.gallery_hint }, :hidden => right_way(tower::CHOI)
  end
end
