module PokeAccess
  # Invisible spots that heal the whole party each time the player steps on or touches them (a healing circle, a bed, a
  # purified zone): a page with no sprite nor tile, run by touch, that heals with no transfer, battle, move of the
  # player or anything that stays changed, a question it asks answered yes. The page is read by the walk the routes use,
  # never run. They are objects, named healing zones; one that heals entered from some sides alone has its route end on
  # the tiles it is entered from (entries), as a one-sided doorway's. A row of them is one target (EventRows).
  module HealingFloors
    # A list a healing spot's page can be: one with Recover All, a healing call or a common event, the walk telling.
    HEAL_HINT = /pbHealAll|heal_party/

    # Whether the engine starts the spot on arrival and the facings it heals from, as [on, facings]; nil for any other
    # event.
    def self.inspect_record(r)
      return nil unless r.page && (r.trigger == 1 || r.trigger == 2)
      return nil unless r.char.to_s.empty? && r.tile.to_i == 0
      return nil unless may_heal?(PokeAccess.ivar(r.ev, :@list))
      return nil if PokeAccess::World::Mechanics.piece_of(r.ev)
      on = PokeAccess::Routes::Effects.fires_on_arrival?(r.ev)
      dirs = [2, 4, 6, 8].select do |d|
        dx, dy = PokeAccess::DIR_DELTA[d]
        o = PokeAccess::EventPages.outcome(r.ev, d, on ? [r.x, r.y] : [r.x - dx, r.y - dy], true)
        o && o.heals && !(o.unknown || o.transfer || o.maybe_transfer || o.battle || o.changes || o.move)
      end
      dirs.empty? ? nil : [on, dirs]
    end

    # Whether a page's list could heal, before walking it: Recover All, a healing call or a common event in it.
    def self.may_heal?(list)
      return false unless list.is_a?(Array)
      list.any? { |c| [PokeAccess::EventPages::RECOVER_ALL, PokeAccess::EventPages::COMMON_EVENT].include?(c.code) } ||
        PokeAccess::Locator.script_calls(list).any? { |s| s =~ HEAL_HINT }
    end

    # What an event's facet says (see inspect_record), or nil.
    def self.reading(ev)
      r = PokeAccess::World::Events.record_of(ev)
      r ? PokeAccess::World::Events.facet(r, :healing_floor) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether an event is a healing spot.
    def self.event?(ev)
      !reading(ev).nil?
    end

    # Whether a route to the spot ends on it: it heals on arrival from every side.
    def self.onto?(ev)
      f = reading(ev)
      f ? (f[0] && f[1].length == 4) : false
    end

    # The tiles a spot at (tx,ty) that heals from some sides alone is entered or touched from; nil for any other target.
    def self.entries(tx, ty)
      r = PokeAccess::World::Events.at(tx, ty).detect { |e| PokeAccess::World::Events.facet(e, :healing_floor) }
      return nil unless r
      dirs = PokeAccess::World::Events.facet(r, :healing_floor)[1]
      return nil if dirs.length == 4
      dirs.map { |d| [tx - PokeAccess::DIR_DELTA[d][0], ty - PokeAccess::DIR_DELTA[d][1]] }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether an event is the one its row of healing spots sounds from (EventRows).
    def self.lead?(ev)
      PokeAccess::EventRows.lead?(:heal, ev)
    end
  end
end

PokeAccess::World::Events.facet_provider(:healing_floor) { |r| PokeAccess::HealingFloors.inspect_record(r) }
PokeAccess::EventRows.kind(:heal) { |ev| PokeAccess::HealingFloors.event?(ev) }
PokeAccess::Locator.register_rule(:name) do |ev|
  PokeAccess::I18n.t(:loc_healing_zone) if PokeAccess::HealingFloors.event?(ev)
end
