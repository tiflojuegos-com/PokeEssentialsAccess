# Revival's obstacles that one of its six characters clears (rocks, fires, electromagnetic fields, brambles, sleeping
# Pokemon and Tunia's terminals): each event has a page that asks for that character's switch (CHARACTER_SWITCHES) and
# offers the choice that clears it, after a first page that only says it cannot be done. While one of those two pages
# is live, the event is named by what it is and who clears it, among the objects. The Black Rose Tower's lobby has two
# more brambles the story alone clears.
module PokeAccess
  module RevivalObstacles
    # The switch of the character who clears an obstacle => what the obstacle is called.
    LABELS = { 104 => :rv_obstacle_sleeping, 105 => :rv_obstacle_terminal, 106 => :rv_obstacle_rock,
               107 => :rv_obstacle_brambles, 108 => :rv_obstacle_fire, 109 => :rv_obstacle_field }
    # Map => brambles no character clears.
    STORY_BRAMBLES = { 238 => [29, 44] }

    # An obstacle's name, kept per page; nil for any other event.
    def self.name(ev)
      PokeAccess::Locator.verdict(ev, :rv_obstacle) { name_uncached(ev) }
    end

    # What the obstacle is and who clears it, while its live page comes no later than the character's page.
    def self.name_uncached(ev)
      return PokeAccess::I18n.t(:rv_obstacle_brambles_story) if story_brambles?(ev)
      pages = PokeAccess::World::Mechanics::Links.pages(ev)
      at = pages.index { |pg| pg.equal?(PokeAccess.ivar(ev, :@page)) }
      i = pages.index { |pg| clearer(pg) }
      return nil unless at && i && at <= i
      sw = clearer(pages[i])
      who = character(sw)
      who ? PokeAccess::I18n.t(LABELS[sw], :who => who) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether the event is one of the story's brambles while they stand.
    def self.story_brambles?(ev)
      (STORY_BRAMBLES[$game_map.map_id] || []).include?(ev.id) && !ev.character_name.to_s.empty? && !ev.through
    end

    # The character switch a page asks for when it also offers a choice; nil otherwise.
    def self.clearer(pg)
      c = pg.condition
      ids = []
      ids.push(c.switch1_id) if c.switch1_valid
      ids.push(c.switch2_id) if c.switch2_valid
      sw = ids.find { |s| LABELS[s] }
      sw && pg.list.any? { |cmd| cmd.code == 102 } ? sw : nil
    end

    # The name of the character whose switch is sw, as the game's PHS calls them.
    def self.character(sw)
      names = PokeAccess.const_at("CHARACTER_NAMES")
      switches = PokeAccess.const_at("CHARACTER_SWITCHES")
      return nil unless names.is_a?(Array) && switches.is_a?(Array)
      i = switches.index(sw)
      i ? names[i] : nil
    end
  end
end

PokeAccess::Game.define("revival") do
  event_name { |ev| PokeAccess::RevivalObstacles.name(ev) }
  event_category(:objects) { |ev| PokeAccess::RevivalObstacles.name(ev) }
end
