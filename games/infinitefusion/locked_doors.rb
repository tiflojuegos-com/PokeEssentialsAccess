module PokeAccess
  module InfiniteFusionLockedDoors
    CAPTAIN_KEY = /\A\s*\$PokemonBag\.pbQuantity\s*\(\s*:CAPTAINSKEY\s*\)\s*>\s*0\s*\z/

    # Read only this key-gated pair of pages; do not expose arbitrary future rooms.
    # The real interpreter still checks the key and opens the door normally.
    def self.destination(event)
      active = PokeAccess.ivar(event, :@page)
      return nil unless active && [0, 1].include?(active.trigger)
      sprite = event.character_name.to_s
      return nil unless sprite.empty? || PokeAccess::Locator.doorway_sprite?(sprite)
      pages = (PokeAccess.ivar(event, :@event).pages rescue nil)
      return nil unless pages.is_a?(Array) && pages.length == 2 && pages[0].equal?(active)
      list = PokeAccess.ivar(event, :@list)
      return nil unless list.is_a?(Array)
      gate = list.find { |c| c.code == 111 && c.parameters[0] == 12 && c.parameters[1].to_s =~ CAPTAIN_KEY }
      return nil unless gate
      start = list.index(gate) + 1
      body = list[start..-1].take_while { |c| c.indent > gate.indent }
      switches = body.select { |c| c.code == 123 && c.parameters[1] == 0 }.map { |c| c.parameters[0] }.uniq
      return nil unless switches.length == 1
      next_page = pages[1]
      condition = next_page.condition
      return nil unless condition.self_switch_valid && condition.self_switch_ch == switches[0]
      return nil if condition.switch1_valid || condition.switch2_valid || condition.variable_valid
      transfers = next_page.list.select { |c| c.code == 201 }
      return nil unless transfers.length == 1
      params = transfers[0].parameters
      params[0] == 0 && params[1].is_a?(Integer) && params[1] > 0 ? params[1] : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion") do
  override("PokeAccess::Locator", :transfer_event?) do |_locator, original, args|
    PokeAccess::InfiniteFusionLockedDoors.destination(args[0]) ? true : original.call
  end
  event_name do |event|
    map_id = PokeAccess::InfiniteFusionLockedDoors.destination(event)
    name = map_id && PokeAccess::Locator.map_name(map_id)
    name && PokeAccess::I18n.t(:loc_locked_exit_to, :map => name)
  end
end
