module PokeAccess
  # Optional targets for active invisible touch scenes that change lasting state. Reads the same page interpreter
  # as routes; it never runs a command or searches inactive pages for future story text.
  module SceneTriggers
    # The facet's activation mode when every approach starts the scene; directional-only outcomes need a narrower
    # route goal than an ordinary floor or adjacent target, so they are left to their existing game-specific rules.
    def self.inspect_record(r)
      return nil unless r.page && (r.trigger == 1 || r.trigger == 2)
      return nil unless r.char.to_s.empty? && r.tile.to_i == 0
      return nil if PokeAccess::World::Mechanics.piece_of(r.ev)
      on = PokeAccess::Routes::Effects.fires_on_arrival?(r.ev)
      [2, 4, 6, 8].each do |direction|
        delta = PokeAccess::DIR_DELTA[direction]
        at = on ? [r.x, r.y] : [r.x - delta[0], r.y - delta[1]]
        outcome = PokeAccess::EventPages.outcome(r.ev, direction, at)
        return nil unless outcome && outcome.talks && outcome.changes
        return nil if outcome.unknown || outcome.transfer || outcome.maybe_transfer
      end
      on ? :onto : :touch
    end

    # The enabled event's cached active-page meaning; flags read while interpreting it invalidate the facet.
    def self.activation(ev)
      return nil unless PokeAccess::Config.scene_guidance
      record = PokeAccess::World::Events.record_of(ev)
      record ? PokeAccess::World::Events.facet(record, :scene_trigger) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True only for an enabled, recognized scene; ordinary names and user tags keep their existing priority.
    def self.event?(ev)
      !activation(ev).nil?
    end

    # Whether the real engine starts this scene on its tile rather than on a bump from beside it.
    def self.onto?(ev)
      activation(ev) == :onto
    end

    # Gates the extra locator category, honoring hidden events and the player's category overrides.
    def self.any?
      return false unless PokeAccess::Config.scene_guidance
      PokeAccess::World::Events.records.any? do |record|
        ev = record.ev
        !PokeAccess::Locator.hidden?(ev) && PokeAccess::Locator.in_category?(ev, :scenes)
      end
    end

    # Optional activation advice, separate from the essential scene label and respecting the help setting.
    def self.instruction(ev)
      return nil unless PokeAccess::Config.read_help && event?(ev)
      PokeAccess::I18n.t(onto?(ev) ? :scene_step_onto : :scene_touch)
    end
  end
end

PokeAccess::World::Events.facet_provider(:scene_trigger) { |record| PokeAccess::SceneTriggers.inspect_record(record) }
PokeAccess::Locator.register_rule(:name) do |ev|
  PokeAccess::I18n.t(:loc_scene_trigger) if PokeAccess::SceneTriggers.event?(ev)
end
PokeAccess::Locator.register_rule(:mark) { |ev| PokeAccess::SceneTriggers.instruction(ev) }
