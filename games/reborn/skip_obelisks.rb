# Reborn's obelisks (White Shard events, drawn obelisk2) offer to skip the puzzle of their map when touched. They stand only
# with the blindstep or nopuzzles password, which their first page checks (switches 2226 and 2227), or with the puzzle already
# done in another save. Named for what they do; with the puzzle assist, a map whose obelisk waits for a password says so on
# arriving.
module PokeAccess
  module RebornObelisks
    NAME = /White Shard/
    BLINDSTEP = 2226
    NO_PUZZLES = 2227

    # The name of an obelisk, or nil for any other event.
    def self.name_of(ev)
      return nil unless ev.name.to_s =~ NAME && ev.character_name.to_s =~ /obelisk/i
      PokeAccess::I18n.t(:reb_obelisk)
    end

    # The password switches an obelisk of this map checks while it waits for one, its puzzle not done; nil for any other
    # event. Its first page is the one that checks them, and shows no obelisk.
    def self.waiting_for(ev)
      return nil unless ev.name.to_s =~ NAME
      links = PokeAccess::World::Mechanics::Links
      pages = links.pages(ev)
      first = pages[0]
      return nil unless first && first.trigger == 3
      return nil unless pages.reverse.find { |pg| links.holds?(pg.condition, ev, {}) }.equal?(first)
      checks = (first.list || []).select { |c| c.code == 111 && c.parameters[0] == 0 }.map { |c| c.parameters[1] }
      checks = checks.select { |s| s == BLINDSTEP || s == NO_PUZZLES }
      checks.empty? || checks.any? { |s| $game_switches[s] } ? nil : checks
    end

    # With the assist, says on arriving that the map's puzzle can be skipped and by which password.
    def self.arrival
      return unless PokeAccess::Puzzles.assist?
      checks = ($game_map.events || {}).values.map { |ev| waiting_for(ev) }.compact.first
      return unless checks
      PokeAccess.speak(PokeAccess::I18n.t(checks.include?(NO_PUZZLES) ? :reb_obelisk_hint : :reb_obelisk_hint_blindstep), false)
    end
  end
end

PokeAccess::Game.define("reborn") do
  event_name { |ev| PokeAccess::RebornObelisks.name_of(ev) }
end

# After the map's name, so the notice follows it.
PokeAccess::Events.on(:map_named) { PokeAccess::RebornObelisks.arrival }
