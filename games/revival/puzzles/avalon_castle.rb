# Castillo Avalon (maps 203 and 204). Each floor has three lit torches: putting one out turns on its switch, puts out one
# of the three fires over the floor's way up and adds 1 to var 123, and the way up opens at 3 on the first floor and at 6
# on the second, which only the first's opens onto. Invisible pedestals dress the player as Zubat (switch 247),
# Raticate (248) or Gastly (249), each turning the other two off: Zubat's and Gastly's open the invisible walls that wait
# for their switch, Raticate's the holes that lead elsewhere on the floor; invisible strips take the disguise off.
module PokeAccess
  module RevivalAvalon
    # Map => { torch event => the switch putting it out turns on }.
    TORCHES = { 203 => { 24 => 277, 55 => 278, 23 => 279 }, 204 => { 55 => 280, 56 => 281, 57 => 282 } }
    # Map => [the way up's events in its bottom row, its other closed tiles, the count of var 123 that opens it].
    DOORS = { 203 => [[41, 56, 57], (58..64), 3], 204 => [[58, 59, 60], (61..67), 6] }
    # Map => { disguise switch => its pedestals }.
    PEDESTALS = { 203 => { 247 => [2, 5, 35, 37, 38, 39], 248 => [6, 7, 28, 29], 249 => [10, 14, 19, 21, 43] },
                  204 => { 247 => [12, 13, 14, 15, 16, 17, 39], 248 => [30, 31, 37], 249 => [8, 9, 10, 11] } }
    # Map => the strips that take the disguise off.
    STRIPS = { 203 => [3, 8, 9, 16, 17, 20, 30, 31, 32, 36, 40],
               204 => [18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 34, 38] }
    # Disguise switch => the species it dresses the player as.
    DISGUISES = { 247 => :ZUBAT, 248 => :RATICATE, 249 => :GASTLY }

    # Whether a torch of this map is still lit.
    def self.lit?(ev)
      sw = (TORCHES[$game_map.map_id] || {})[ev.id]
      sw ? !$game_switches[sw] : false
    end

    # A torch's name by whether it is lit.
    def self.torch_name(ev)
      PokeAccess::I18n.t(lit?(ev) ? :rv_avalon_torch_lit : :rv_avalon_torch_out)
    end

    # Whether this floor's way up still waits for its torches; its closed tiles are named only meanwhile.
    def self.closed?
      door = DOORS[$game_map.map_id]
      door ? $game_variables[123] < door[2] : false
    end

    # The species a disguise switch dresses the player as, in the game's language.
    def self.species(sw)
      PokeAccess::Data.species_name(DISGUISES[sw])
    end

    # The disguise the player wears, as a phase says it.
    def self.disguise(sw)
      PokeAccess::I18n.t(:rv_disguise, :pokemon => species(sw))
    end

    # The disguise a pedestal of this map puts on.
    def self.pedestal_name(ev)
      sw = (PEDESTALS[$game_map.map_id] || {}).find { |_s, ids| ids.include?(ev.id) }
      sw ? PokeAccess::I18n.t(:rv_disguise_pedestal, :pokemon => species(sw[0])) : nil
    end

    # The assist's rule of the disguises: what each one opens and what takes it off.
    def self.rule
      PokeAccess::I18n.t(:rv_disguise_hint, :zubat => species(247), :raticate => species(248), :gastly => species(249))
    end
  end
end

PokeAccess::Game.define("revival") do
  avalon = PokeAccess::RevivalAvalon
  avalon::TORCHES.each do |map, torches|
    bottom, rest, opens_at = avalon::DOORS[map]
    mechanic(:state, map, :part => :torches) do
      auto
      name torches.keys, lambda { |ev| avalon.torch_name(ev) }, :when => lambda { |ev| avalon.lit?(ev) }
      name bottom, lambda { |_ev| avalon.closed? ? PokeAccess::I18n.t(:rv_avalon_way_up) : nil }, :grouped => true
      hide rest
      count :rv_avalon_torches_out, :switches => torches.values
      solved { $game_variables[123] >= opens_at }
      hint :rv_avalon_torches_hint
    end
  end

  avalon::PEDESTALS.each do |map, pedestals|
    mechanic(:state, map, :part => :disguise) do
      auto
      name pedestals.values.flatten, lambda { |ev| avalon.pedestal_name(ev) }
      avoid avalon::STRIPS[map], :assist => true
      avalon::DISGUISES.keys.each do |sw|
        phase lambda { $game_switches[sw] }, :title => lambda { avalon.disguise(sw) }
      end
      phase lambda { true }, :title => :rv_disguise_none
      hint lambda { avalon.rule }
    end
  end
end
