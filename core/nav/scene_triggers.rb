module PokeAccess
  # Invisible events that start a scene, located only with scene_triggers on (off by default: knowing where a scene
  # waits gives part of it away): an active page with no sprite nor tile, run by touch, that from every side says
  # something and changes something that stays, with no transfer. The page is read by the walk the routes use, never
  # run. Neighbouring triggers running the same page are one scene (EventRows): one target, sounding from its middle.
  module SceneTriggers
    # How the engine starts a recognized scene: :onto on its tile, :touch from beside it; nil for any other event.
    def self.inspect_record(r)
      return nil unless r.page && (r.trigger == 1 || r.trigger == 2)
      return nil unless r.char.to_s.empty? && r.tile.to_i == 0
      return nil if PokeAccess::World::Mechanics.piece_of(r.ev)
      on = PokeAccess::Routes::Effects.fires_on_arrival?(r.ev)
      [2, 4, 6, 8].each do |d|
        dx, dy = PokeAccess::DIR_DELTA[d]
        o = PokeAccess::EventPages.outcome(r.ev, d, on ? [r.x, r.y] : [r.x - dx, r.y - dy])
        return nil unless o && o.talks && o.changes
        return nil if o.unknown || o.transfer || o.maybe_transfer
      end
      on ? :onto : :touch
    end

    # How a scene trigger starts (see inspect_record), with scene_triggers on; nil otherwise.
    def self.activation(ev)
      return nil unless PokeAccess::Config.scene_triggers
      r = PokeAccess::World::Events.record_of(ev)
      r ? PokeAccess::World::Events.facet(r, :scene_trigger) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether an event is a scene trigger the locator offers.
    def self.event?(ev)
      !activation(ev).nil?
    end

    # Whether the engine starts the scene on its tile, so a route to it ends there.
    def self.onto?(ev)
      activation(ev) == :onto
    end

    # Whether the map has a scene trigger the locator would list, which adds the scenes category.
    def self.any?
      return false unless PokeAccess::Config.scene_triggers
      $game_map.events.values.any? { |ev| !PokeAccess::Locator.hidden?(ev) && event?(ev) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The facet of an event, whether or not scene_triggers is on: which events form a row does not depend on it.
    def self.activation_of(ev)
      r = PokeAccess::World::Events.record_of(ev)
      r ? PokeAccess::World::Events.facet(r, :scene_trigger) : nil
    end

    # Whether an event is the one its row of scene triggers sounds from (EventRows).
    def self.lead?(ev)
      PokeAccess::EventRows.lead?(:scene, ev)
    end
  end
end

PokeAccess::World::Events.facet_provider(:scene_trigger) { |r| PokeAccess::SceneTriggers.inspect_record(r) }
PokeAccess::EventRows.kind(:scene) { |ev| !PokeAccess::SceneTriggers.activation_of(ev).nil? }
PokeAccess::Locator.register_rule(:name) do |ev|
  PokeAccess::I18n.t(:loc_scene_trigger) if PokeAccess::SceneTriggers.event?(ev)
end
PokeAccess::Events.on(:config_changed) do |key|
  PokeAccess::Sound::Scheduler.forget_scan if key == :scene_triggers
end
