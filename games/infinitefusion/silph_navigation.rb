# Silph Co. in Infinite Fusion Kanto uses floor pads with tile 734, separate
# staircase events and entrances to the elevator on map 212.
module PokeAccess
  module IFSilphNavigation
    FLOORS = {
      121 => 1, 660 => 2, 661 => 3, 662 => 4, 663 => 5,
      758 => 6, 665 => 7, 666 => 8, 667 => 9, 668 => 10
    }
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

    def self.map_id(event)
      PokeAccess.ivar(event, :@map_id) || ($game_map.map_id rescue nil)
    end

    # The original Rock Et marker changes the screen tone on its parallel page.
    def self.empty_rocket_marker?(event)
      return false unless FLOORS.key?(map_id(event)) && event.name == "Rock Et" &&
                          event.x == 0 && event.y == 0 && event.character_name.to_s.empty? &&
                          event.tile_id == 0 && [0, 4].include?(event.trigger)

      list = PokeAccess.ivar(event, :@list)
      allowed = event.trigger == 4 ? [0, 116, 223] : [0]
      list.is_a?(Array) && list.all? { |command| allowed.include?(command.code) }
    end

    def self.label(event)
      map = map_id(event)
      return nil unless FLOORS.key?(map) && event.trigger == 1

      pad = event.tile_id == PAD_TILE
      elevator = ELEVATOR_ENTRANCES[map] == event.id
      stairs = STAIRS[map].include?(event.id)
      return nil unless pad || elevator || stairs
      return nil if PokeAccess::Puzzles.piece_name(event)

      transfer = PokeAccess::Locator.walked_transfer(event)
      return nil unless transfer
      destination = transfer.first
      return PokeAccess::I18n.t(:ifx_silph_elevator) if elevator && destination == ELEVATOR_MAP

      floor = FLOORS[destination]
      return nil unless floor
      if pad
        key = destination == map ? :ifx_silph_teleport_on : :ifx_silph_teleport_to
      elsif stairs && destination != map
        key = :ifx_silph_stairs_to
      end
      PokeAccess::I18n.t(key, :floor => "#{floor}F") if key
    end
  end
end

PokeAccess::Game.define("infinitefusion") do
  event_hidden { |event| PokeAccess::IFSilphNavigation.empty_rocket_marker?(event) }
  event_name { |event| PokeAccess::IFSilphNavigation.label(event) }
end
