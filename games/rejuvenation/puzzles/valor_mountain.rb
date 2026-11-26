# Valor Mountain: the same two floors in three energies, each its own map. A crystal takes the player one tile down in
# another version; its colour tells which. The source crystals, in the order valor, neutral, calm, unlock the red
# (switch 576), green (575) and blue (577) ones. Variable 181 goes 42 to 43 at Valor Cliffside.
module PokeAccess
  module RejuvValor
    MAPS = { 139 => :neutral, 140 => :valor, 146 => :calm, 6 => :neutral, 42 => :valor, 45 => :calm }
    FLOORS = [[139, 140, 146], [6, 42, 45]]
    SMALL = { 2 => :rj_valor_crystal_red, 4 => :rj_valor_crystal_blue, 6 => :rj_valor_crystal_green,
              8 => :rj_valor_crystal_grey }
    SOURCE = { 4 => :rj_valor_source_red, 2 => :rj_valor_source_blue, 6 => :rj_valor_source_green,
               8 => :rj_valor_source_grey }
    LOOKS = { :neutral => :rj_valor_look_neutral, :valor => :rj_valor_look_valor, :calm => :rj_valor_look_calm }
    # Per map, [stage, box the player stands in, event to reach next]; the first that holds wins.
    PLAN = {
      139 => [[:b_calm, [129, 135, 27, 50], 23], [:b, [129, 135, 27, 50], 41], [:b, [78, 86, 11, 48], 17],
              [:b, [75, 81, 92, 100], 39], [:b_calm, [114, 151, 51, 96], 25], [:b, [114, 151, 51, 96], 22],
              [:b, [74, 82, 65, 79], 18], [:b, [4, 46, 63, 100], 10], [:b_calm, [5, 44, 9, 51], 4],
              [:any, [16, 18, 32, 32], 51], [:any, [4, 46, 63, 100], 19], [:any, [5, 44, 9, 51], 8]],
      140 => [[:b_neutral, [130, 134, 69, 73], 81], [:b, [130, 134, 69, 73], 9], [:b_neutral, [78, 86, 11, 48], 19],
              [:b, [78, 86, 11, 48], 73], [:b, [74, 82, 65, 79], 26], [:b_calm, [114, 150, 39, 96], 56],
              [:b, [114, 150, 39, 96], 6], [:b_calm, [7, 44, 7, 51], 27], [:any, [75, 81, 92, 101], 61],
              [:any, [5, 6, 13, 17], 11], [:any, [7, 44, 7, 51], 28], [:any, [4, 46, 63, 100], 16]],
      146 => [[:any, [14, 20, 25, 31], 26], [:b, [73, 78, 18, 27], 55], [:b, [111, 151, 6, 38], 33],
              [:b, [114, 151, 51, 96], 20], [:b, [59, 82, 65, 89], 30], [:b, [59, 81, 90, 101], 49],
              [:b, [78, 86, 11, 48], 31], [:b_calm, [7, 56, 7, 52], 63], [:valor, [7, 56, 7, 52], 12],
              [:any, [7, 56, 7, 52], 26], [:valor, [4, 46, 63, 100], 25], [:any, [4, 46, 63, 100], 13],
              [:any, [5, 6, 13, 17], 23]],
      6 => [[:b, [22, 40, 59, 67], 11], [:a, [22, 40, 59, 67], 14], [:any, [4, 34, 77, 91], 17],
            [:any, [5, 12, 56, 64], 16], [:any, [11, 39, 6, 38], 28]],
      42 => [[:any, [11, 39, 6, 34], 10]],
      45 => [[:b, [57, 67, 7, 24], 16], [:any, [11, 39, 6, 39], 1]]
    }
    # Where Magma Drift is needed to reach the next step, by map.
    MAGMA = { 140 => [[7, 44, 7, 51], [114, 150, 39, 96]] }

    # True until Valor Cliffside.
    def self.live?
      $game_variables[181].to_i < 43
    end

    # Whether a stage of the plan holds now.
    def self.stage?(stage)
      v = $game_variables[181].to_i
      case stage
      when :a then v < 42
      when :b then v == 42
      when :valor then $game_switches[576] ? true : false
      when :b_neutral then v == 42 && $game_switches[575]
      when :b_calm then v == 42 && $game_switches[577]
      else true
      end
    end

    # True while the player stands in a box [x0, x1, y0, y1].
    def self.in?(box)
      x = $game_player.x
      y = $game_player.y
      x >= box[0] && x <= box[1] && y >= box[2] && y <= box[3]
    end

    # The event to reach next on a map, or nil.
    def self.target(map)
      return nil unless live? && $game_map.map_id == map
      row = (PLAN[map] || []).find { |stage, box, _ev| stage?(stage) && in?(box) }
      row ? row[2] : nil
    end

    # The assisted hint: the next step, saying when the lava needs Magma Drift.
    def self.hint(map)
      return nil unless target(map)
      (MAGMA[map] || []).any? { |box| in?(box) } ? :rj_valor_hint_magma : :rj_valor_hint
    end

    # A crystal's colour, by the row of its page's graphic; the sources have their own rows.
    def self.crystal_label(ev)
      page = PokeAccess.ivar(ev, :@page)
      dir = (page.graphic.direction rescue ev.direction).to_i
      ev.character_name.to_s =~ /_1\z/ ? SOURCE[dir] : SMALL[dir]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  valor = PokeAccess::RejuvValor
  valor::MAPS.each do |map, energy|
    others = valor::FLOORS.find { |f| f.include?(map) } - [map]
    mechanic(:state, map, :part => :valor_crystals) do
      auto
      name(/\Aobject_valorcryst(_1)?\z/, lambda { |ev| valor.crystal_label(ev) })
      sent_back :rj_valor_shift, :maps => others
      look = valor::LOOKS[energy]
      (valor::PLAN[map] || []).map { |row| row[2] }.uniq.each do |id|
        spot :event => id, :label => :rj_valor_next, :assist => true, :when => lambda { valor.target(map) == id }
        phase(lambda { PokeAccess::Puzzles.assist? && valor.target(map) == id }, :title => look, :quiet => true,
              :entry_title => true, :hint => lambda { valor.hint(map) })
      end
      phase(lambda { true }, :title => look, :quiet => true, :entry_title => true)
      solved(nil, :quiet => true) { !valor.live? }
    end
  end
end
