# Ashen Frost's Abandoned Pokémon Center (map 775, Case Twenty): variable 349 counts three finds, then the doctor (EV2)
# takes the complaint and counts the house in variable 353. The finds are one of the blood stains (EV3 to EV5, all
# turned by looking at any), the vending machine (EV7, a touch with no graphic) and Audino (EV8).
module PokeAccess
  module AshenMedicalHouse
    MAP = 775
    COUNT = 349
    NEEDED = 3
    BLOOD = [3, 4, 5]
    VENDING = 7
    AUDINO = 8

    # The count variable's value.
    def self.count
      $game_variables[COUNT].to_i
    end

    # Whether an event has been counted: its self switch A.
    def self.found?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # Whether a blood stain has been looked at.
    def self.blood_found?
      BLOOD.any? { |id| found?(id) }
    end

    # What has been found, as the doctor counts it.
    def self.found
      [count, NEEDED].min
    end

    # The assist's line: what is left to look at, then the doctor.
    def self.hint
      v = count
      return nil if v > NEEDED
      return :afd_center_doctor if v == NEEDED
      left = []
      left.push(PokeAccess::I18n.t(:afd_center_item_blood)) unless blood_found?
      left.push(PokeAccess::I18n.t(:afd_center_item_vending)) unless found?(VENDING)
      left.push(PokeAccess::I18n.t(:afd_center_item_audino)) unless found?(AUDINO)
      left.empty? ? nil : [:afd_center_left, { :list => left.join("; ") }]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  center = PokeAccess::AshenMedicalHouse
  mechanic(:state, center::MAP, :part => :afd_medical) do
    auto
    name center::BLOOD, :afd_center_blood, :when => lambda { |_ev| !center.blood_found? }
    name center::VENDING, :afd_center_vending, :when => lambda { |_ev| !center.found?(center::VENDING) }
    count :afd_center_count, :value => lambda { center.found }, :of => center::NEEDED, :assist => true, :hide_zero => true
    hint lambda { center.hint }
    solved(nil, :quiet => true) { center.count > center::NEEDED }
  end
end
