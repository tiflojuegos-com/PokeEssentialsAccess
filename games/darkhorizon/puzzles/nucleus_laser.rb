# Shadow HQ's central room (map 110): a laser (events 25 to 31, x 56) splits it in two. The panel on the east side (event 43)
# turns it off (switch 171) when the bag holds the Nucleus card, which a scientist drops after a battle in the west; without
# it the panel only says what it is for.
module PokeAccess
  module DHNucleus
    # The hint: use the card at the panel when held, else where it comes from.
    def self.hint
      bag = $bag
      held = bag && bag.has?(:KEY_HQ_NUCLEUS)
      PokeAccess::I18n.t(held ? :dh_o_nucleus_have : :dh_o_nucleus_from)
    end

    # True once the player has stood in the room during this visit to the map, so its rule is said once per visit.
    def self.visited?(inside)
      events = $game_map.events
      unless @visit.equal?(events)
        @visit = events
        @inside = false
      end
      @inside ||= inside
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  mechanic(:state, 110) do
    auto
    name 43, lambda { |_ev| PokeAccess::Puzzles.assist? ? :dh_o_nucleus_panel_card : :dh_o_nucleus_panel }
    name 25..31, :dh_o_laser_wall, :grouped => true, :when => lambda { |_ev| !$game_switches[171] }
    room = at(47, 64, 6, 16)
    phase lambda { PokeAccess::DHNucleus.visited?(room.call) && !$game_switches[171] }, :title => :dh_o_nucleus_rule,
          :hint => lambda { PokeAccess::DHNucleus.hint }
    solved { $game_switches[171] }
  end
end
