# Infinite Fusion's door to the captain's cabin on the S.S. Anne (Map027, events 3 and 4): its first page only opens
# with the Captain's Key, by setting the self switch that turns on the second page, the one holding the transfer. The
# locator lists it with the exits as a locked door to the cabin; the game still checks the key when it is used.
module PokeAccess
  module InfiniteFusionLockedDoors
    # The first page's key check, as the game writes it in a conditional branch's script.
    CAPTAIN_KEY = /\A\s*\$PokemonBag\.pbQuantity\s*\(\s*:CAPTAINSKEY\s*\)\s*>\s*0\s*\z/

    # The map a key-locked door leads to, kept per page (Locator.verdict); nil for any other event.
    def self.destination(event)
      PokeAccess::Locator.verdict(event, :if_locked_door) { destination_uncached(event) }
    end

    # The map behind a door (no sprite, or a doorway's) whose active page is the first of two, run by the action key or
    # by touch, and sets on the key check the one self switch that alone turns on the second page, whose single transfer
    # to a fixed map leads there; nil for any other event.
    def self.destination_uncached(event)
      active = PokeAccess.ivar(event, :@page)
      return nil unless active && [0, 1].include?(active.trigger)
      sprite = event.character_name.to_s
      return nil unless sprite.empty? || PokeAccess::Locator.doorway_sprite?(sprite)
      pages = (PokeAccess.ivar(event, :@event).pages rescue nil)
      return nil unless pages.is_a?(Array) && pages.length == 2 && pages[0].equal?(active)
      switch = unlock_switch(PokeAccess.ivar(event, :@list))
      switch && transfer_map(pages[1], switch)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The self switch the key check's branch sets, when it sets exactly one; nil otherwise.
    def self.unlock_switch(list)
      return nil unless list.is_a?(Array)
      gate = list.find { |c| c.code == 111 && c.parameters[0] == 12 && c.parameters[1].to_s =~ CAPTAIN_KEY }
      return nil unless gate
      body = list[(list.index(gate) + 1)..-1].take_while { |c| c.indent > gate.indent }
      switches = body.select { |c| c.code == 123 && c.parameters[1] == 0 }.map { |c| c.parameters[0] }.uniq
      switches.length == 1 ? switches[0] : nil
    end

    # The fixed map of the page's only transfer, when that self switch is the page's only condition; nil otherwise.
    def self.transfer_map(page, switch)
      cond = page.condition
      return nil unless cond.self_switch_valid && cond.self_switch_ch == switch
      return nil if cond.switch1_valid || cond.switch2_valid || cond.variable_valid
      transfers = page.list.select { |c| c.code == 201 }
      return nil unless transfers.length == 1
      params = transfers[0].parameters
      params[0] == 0 && params[1].is_a?(Integer) && params[1] > 0 ? params[1] : nil
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
