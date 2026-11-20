# The turnstiles of Epoch Corporation HQ (maps 395 and 396) and the Destroyed Lab (maps 8 and 9): rings of nine "Escalator"
# events whose four arms, stepped on, carry the player across the ring and flip its switch, and whose panels ("Rotary N CP")
# flip it too. With the switch off an arm sends the player out the side after it counterclockwise (west to south), with it
# on clockwise (west to north), as the rings' pages do (checked with _pulido/sim/soulstones2/rotaries.rb). An arm names the
# side it leads to now, as the ring's drawing shows it; the gates the panels lower are said by the core as they open.
module PokeAccess
  module SS2Turnstiles
    RINGS = { 395 => [[34, 46, 270]], 396 => [[21, 68, 271]], 8 => [[77, 49, 277]],
              9 => [[43, 19, 278], [25, 47, 279], [25, 66, 276]] }
    SIDES = { [0, -1] => :north, [1, 0] => :east, [0, 1] => :south, [-1, 0] => :west }
    OFF = { :west => :south, :north => :west, :south => :east, :east => :north }
    ON = { :west => :north, :north => :east, :south => :west, :east => :south }

    # The ring an event is an arm of, and the arm's side, or nil for a corner, the centre or another event.
    def self.arm(map, ev)
      (RINGS[map] || []).each do |cx, cy, switch|
        side = SIDES[[ev.x - cx, ev.y - cy]]
        return [side, switch] if side
      end
      nil
    end

    # True while the arm's page carries the player: one started by touch.
    def self.live?(ev)
      page = ev.instance_variable_get(:@page)
      page ? page.trigger == 1 : false
    end

    # An arm's name: the side of the ring it lets out on now; nil leaves any other event its own name.
    def self.label(map, ev)
      found = arm(map, ev)
      return nil unless found && live?(ev)
      side, switch = found
      out = ($game_switches[switch] ? ON : OFF)[side]
      [:ss2_pz_turnstile, { :side => PokeAccess::I18n.t("ss2_pz_side_#{out}".to_sym) }]
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  PokeAccess::SS2Turnstiles::RINGS.each_key do |map|
    mechanic(:state, map, :part => :turnstiles) do
      auto
      name(/Escalator/, lambda { |ev| PokeAccess::SS2Turnstiles.label(map, ev) },
           :when => lambda { |ev| !PokeAccess::SS2Turnstiles.label(map, ev).nil? })
      hide(/Escalator/, :when => lambda { |ev| PokeAccess::SS2Turnstiles.arm(map, ev).nil? })
      name(/Rotary \d+ CP/, :ss2_pz_rotary_panel)
      name(/Gate \d+ CP/, :ss2_pz_gate_panel)
    end
  end
end
