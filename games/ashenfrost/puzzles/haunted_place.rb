# Ashen Frost's Haunted Place (map 774, Case Twenty), by variable 348: the objects past the west door (EV13 to EV15) set
# 1, Ramira (EV6, EV16) 2 and 3, and the tile at (12,30) (EV21) makes the player Truffles (switch 71). Ghosts (EV24 to
# EV26) add 1 each; at 6 the smelling ends (EV27) and the owner (EV7) counts the house in variable 353.
module PokeAccess
  module AshenHauntedHouse
    MAP = 774
    STAGE = 348
    TRUFFLES = 71
    TRUFFLES_AT = [12, 30]
    GHOSTS = [24, 25, 26]

    # The house's stage.
    def self.stage
      $game_variables[STAGE].to_i
    end

    # Whether the player is playing as Truffles.
    def self.smelling?
      $game_switches[TRUFFLES] ? true : false
    end

    # Whether a ghost that counts has been talked to: its self switch A.
    def self.found?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # The ghosts talked to, as the stage counts them.
    def self.ghosts
      [[stage - 3, 0].max, GHOSTS.length].min
    end

    # The assist's line for the stage.
    def self.hint
      v = stage
      return :afd_haunted_west if v == 0
      return :afd_haunted_ramira if v == 1
      return :afd_haunted_ramira_west if v == 2
      return (smelling? ? [:afd_haunted_ghosts, { :n => 6 - v }] : :afd_haunted_truffles) if v < 6
      v == 6 && !smelling? ? :afd_haunted_owner : nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  haunted = PokeAccess::AshenHauntedHouse
  mechanic(:state, haunted::MAP, :part => :afd_haunted) do
    auto
    name haunted::GHOSTS, :afd_haunted_ghost, :assist => true,
         :when => lambda { |ev| haunted.smelling? && !haunted.found?(ev.id) }
    spot :at => haunted::TRUFFLES_AT, :label => :afd_haunted_truffles_spot, :onto => true, :assist => true,
         :when => lambda { haunted.stage == 3 && !haunted.smelling? }
    count :afd_haunted_count, :value => lambda { haunted.ghosts }, :of => haunted::GHOSTS.length, :assist => true,
                              :hide_zero => true
    right_choice 6, :takes => { :var => haunted::STAGE }
    hint lambda { haunted.hint }
    solved(nil, :quiet => true) { haunted.stage >= 7 }
  end
end
