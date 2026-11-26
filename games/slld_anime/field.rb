# Dullfern Forest's spider webs (map 25): CutTree action events drawn with web tiles that any protagonist clears by
# using them (variables 78 to 83 and 87 go to 1), so a web is named as one and asks for no field move; its page tests
# the assignment "$player.character_ID = 1", true for everyone. Also the gyms' battle tiles, which the gym puzzles name.
module PokeAccess
  module SlldField
    WEB_TEST = "$player.character_ID = 1"

    # True for a CutTree whose first page is a web's: its script test is the assignment, not pbCut.
    def self.web?(ev)
      return false unless (ev.name.to_s rescue "") == "CutTree"
      pages = (PokeAccess.ivar(ev, :@event).pages rescue nil)
      list = pages.is_a?(Array) && pages[0] ? (pages[0].list || []) : []
      list.any? { |c| (c.code rescue 0) == 111 && (c.parameters[1] rescue nil) == WEB_TEST }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True while a web still stands: its page draws the web's tile.
    def self.standing_web?(ev)
      web?(ev) && (ev.tile_id.to_i > 0 rescue false)
    end

    # True while a gym's battle tile (event_id on this map) waits for the player: its page starts the battle only for a
    # player who arrives facing west.
    def self.battle_tile?(event_id)
      ev = $game_map.events[event_id]
      list = PokeAccess.ivar(ev, :@list)
      list.is_a?(Array) && list.any? do |c|
        (c.code rescue 0) == 111 && (c.parameters[0] rescue nil) == 6 && (c.parameters[2] rescue nil) == 4
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end
  end
end

PokeAccess::Game.define("slld_anime") do
  override("PokeAccess::Locator", :fieldmove_label) do |_mod, original, args|
    PokeAccess::SlldField.web?(args[0]) ? nil : original.call
  end
  event_name { |ev| PokeAccess::I18n.t(:slld_web) if PokeAccess::SlldField.standing_web?(ev) }
  event_category(:objects) { |ev| PokeAccess::SlldField.standing_web?(ev) }
  script_condition(/\A\$player\.character_ID = 1\z/) { |_match, _context| true }
end
