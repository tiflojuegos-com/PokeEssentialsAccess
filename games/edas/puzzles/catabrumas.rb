# Edas' Catabrumas (map 128): four torches far apart are lit in an order only their event names carry, one to each corner of
# the room. Variable 72 counts the right ones and lights the four torches of the middle in turn, far from the ones lit, so the
# count is the assist's; a torch out of turn puts them all out, which the game says. All four lay the platform north of the
# middle, to Lóbrego's hall.
module PokeAccess
  module EdasCatabrumas
    MAP = 128
    ORDER = 72
    TORCHES = [[7, :dir_se], [6, :dir_ne], [5, :dir_no], [8, :dir_so]]

    # How many torches stand lit in turn.
    def self.lit
      [[$game_variables[ORDER].to_i, 0].max, TORCHES.length].min
    end

    # A torch's name in the lists, lit or out as it is drawn.
    def self.torch_name(id)
      TORCHES.index(TORCHES.assoc(id)) < lit ? :edas_cata_torch_lit : :edas_cata_torch_out
    end

    # The assist's line for torch i: the corner it stands in.
    def self.next_line(i)
      what = PokeAccess::I18n.t(:edas_cata_torch_at, :dir => PokeAccess::I18n.t(TORCHES[i][1]))
      PokeAccess::I18n.t(:edas_next, :what => what)
    end
  end
end

PokeAccess::Game.define("edas") do
  cata = PokeAccess::EdasCatabrumas
  mechanic(:state, cata::MAP) do
    auto
    name cata::TORCHES.map { |id, _dir| id }, lambda { |ev| cata.torch_name(ev.id) }
    count :edas_cata_lit, :var => cata::ORDER, :of => cata::TORCHES.length, :hide_zero => true, :assist => true, :reset => false
    arrival_hint :edas_cata_rule
    solved { cata.lit == cata::TORCHES.length }
    cata::TORCHES.each_with_index do |(id, _dir), i|
      phase lambda { cata.lit == i }, :hint => lambda { cata.next_line(i) }, :hidden => right_way(id)
    end
  end
end
