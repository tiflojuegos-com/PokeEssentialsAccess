# Silph Co. in Infinite Fusion Kanto, 1F (map 121) to 10F (6F is map 758): names its floor pads (tile 734), stairs and
# elevator entrances (map 212) by the floor they lead to, and hides the editor's invisible Rock Et marker there.
module PokeAccess
  module IFSilphNavigation
    FLOORS = [121, 660, 661, 662, 663, 758, 665, 666, 667, 668]
    ELEVATOR_ENTRANCES = {
      121 => 13, 660 => 20, 661 => 28, 662 => 7, 663 => 35,
      758 => 28, 665 => 33, 666 => 30, 667 => 35, 668 => 25
    }
    STAIRS = {
      121 => [6], 660 => [7, 8], 661 => [10, 11], 662 => [8, 27],
      663 => [7, 8], 758 => [5, 6], 665 => [6, 7], 666 => [7, 8],
      667 => [5, 6], 668 => [7]
    }
    ELEVATOR_MAP = 212
    PAD_TILE = 734

    # The map the event stands on: the one it keeps, else the player's.
    def self.map_id(event)
      PokeAccess.ivar(event, :@map_id) || ($game_map.map_id rescue nil)
    end

    # True for the editor's invisible Rock Et marker on a floor: undrawn at (0, 0), doing nothing but tint the screen.
    def self.empty_rocket_marker?(event)
      return false unless FLOORS.include?(map_id(event)) && event.name == "Rock Et" &&
                          event.x == 0 && event.y == 0 && event.character_name.to_s.empty? &&
                          event.tile_id == 0 && [0, 4].include?(event.trigger)

      list = PokeAccess.ivar(event, :@list)
      allowed = event.trigger == 4 ? [0, 116, 223] : [0]
      list.is_a?(Array) && list.all? { |command| allowed.include?(command.code) }
    end

    # The name of a floor's pad, staircase or elevator entrance by where its touch transfer leads. Nil for any other
    # event, one a puzzle names, and a transfer off the floors or to a map the game gives no name.
    def self.label(event)
      map = map_id(event)
      return nil unless FLOORS.include?(map) && event.trigger == 1

      pad = event.tile_id == PAD_TILE
      elevator = ELEVATOR_ENTRANCES[map] == event.id
      stairs = STAIRS[map].include?(event.id)
      return nil unless pad || elevator || stairs
      return nil if PokeAccess::Puzzles.piece_name(event)

      transfer = PokeAccess::Locator.walked_transfer(event)
      return nil unless transfer
      destination = transfer.first
      return PokeAccess::I18n.t(:ifx_silph_elevator) if elevator && destination == ELEVATOR_MAP
      return nil unless FLOORS.include?(destination)

      key = if pad
              destination == map ? :ifx_silph_teleport_on : :ifx_silph_teleport_to
            elsif stairs && destination != map
              :ifx_silph_stairs_to
            end
      floor = key && PokeAccess::Locator.map_name(destination)
      floor ? PokeAccess::I18n.t(key, :floor => floor) : nil
    end
  end
end

PokeAccess::Game.define("infinitefusion") do
  event_hidden { |event| PokeAccess::IFSilphNavigation.empty_rocket_marker?(event) }
  event_name { |event| PokeAccess::IFSilphNavigation.label(event) }
end
