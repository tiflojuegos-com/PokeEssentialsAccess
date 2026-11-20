# Veilstone Isle's Shadow Lab (maps 99 to 106): doors that want the key card and a code, the codes being switches the doors
# read by themselves. The card is the one Randall drops (map 102, event 56, switch 143); code 1 is the paper of map 103
# (event 29, switch 139) and wants the card; code 2 is overheard in map 104's corridor (event 42, switch 140); code 3 is
# Orville's (map 104, event 47, switch 141); code 4 is the notebook of the worker the door of code 3 lets out (map 99,
# event 119, switch 142), and the door at the far end of map 105 (event 18) and its laser (event 26) take it.
# The doors read only their code switch, never the card, which only the paper wants. The central zone (map 99) opens with
# code 1, and from it map 100 and map 105 lead to the sensor corridor of map 104 (code 2), which opens Orville's room
# (code 3), whose door lets into the worker's room (code 4); the far door is reached from the entrance room.
module PokeAccess
  module DHShadowLab
    CODES = { 1 => 139, 2 => 140, 3 => 141, 4 => 142 }
    DOORS = { 101 => { 43 => 1 }, 102 => { 52 => 3 }, 104 => { 25 => 2 }, 105 => { 18 => 4 } }

    # The codes known, as numbers.
    def self.known
      CODES.keys.sort.select { |n| $game_switches[CODES[n]] }
    end

    # A door's name: with the assist, the code it takes.
    def self.door(map, ev)
      PokeAccess::Puzzles.assist? ? [:dh_pz_lab_door_code, { :n => DOORS[map][ev.id] }] : :dh_pz_lab_door
    end

    # The info key's line: whether the key card is held and, with the assist, the codes known (the game never numbers them).
    def self.info
      t = PokeAccess::I18n
      card = t.t($game_switches[143] ? :dh_pz_yes : :dh_pz_no)
      return t.t(:dh_pz_lab_card, :card => card) unless PokeAccess::Puzzles.assist?
      codes = known.empty? ? t.t(:dh_pz_none) : known.join(", ")
      t.t(:dh_pz_lab_info, :card => card, :codes => codes)
    end

    # The piece to get next and where it is. The door graph forces one order: the card for the paper, the paper for the
    # central zone, that zone for the sensor, the sensor for Orville, Orville for the worker's notebook, then the far door.
    def self.next_step
      return [:dh_pz_lab_h_card, :dh_x_lab_w_card] unless $game_switches[143]
      CODES.keys.sort.each do |n|
        return ["dh_pz_lab_h_code#{n}".to_sym, "dh_x_lab_w_code#{n}".to_sym] unless $game_switches[CODES[n]]
      end
      [:dh_pz_lab_h_end, :dh_x_lab_w_end]
    end

    # The hint: the whole order while nothing is held, then the next piece and where it is.
    def self.hint
      t = PokeAccess::I18n
      parts = next_step.map { |k| t.t(k) }
      parts.unshift(t.t(:dh_x_lab_order)) unless $game_switches[143] || !known.empty?
      PokeAccess.sentences(parts)
    end

    # What a code door leads to, said with the assist as the door is used.
    def self.leads(map, ev)
      "dh_x_lab_leads#{DOORS[map][ev.id]}".to_sym
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  [99, 100, 101, 102, 103, 104, 105, 106].each do |map|
    mechanic(:state, map) do
      auto
      doors = PokeAccess::DHShadowLab::DOORS[map]
      name doors.keys, lambda { |ev| PokeAccess::DHShadowLab.door(map, ev) } if doors
      on_use doors.keys, lambda { |ev| PokeAccess::DHShadowLab.leads(map, ev) }, :assist => true if doors
      name 29, :dh_pz_lab_paper, :when => lambda { |_ev| !$game_switches[139] } if map == 103
      name 26, :dh_pz_laser, :when => lambda { |_ev| !$game_switches[142] } if map == 105
      spot :event => 42, :label => :dh_pz_lab_code2_spot, :assist => true, :when => lambda { !$game_switches[140] } if map == 104
      solved { $game_switches[138] }
      info { PokeAccess::DHShadowLab.info }
      hint lambda { PokeAccess::DHShadowLab.hint }
    end
  end
end
