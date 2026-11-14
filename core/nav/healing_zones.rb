module PokeAccess
  # Active invisible healing floors. Their original interpreter performs all healing.
  # A directional floor is offered by its approach tile, with a normal manual step into the zone.
  module HealingZones
    # The active page is walked without execution for each arrival direction, tracking live flag dependencies.
    def self.inspect_record(record)
      return nil unless record.page && [1, 2].include?(record.trigger)
      return nil unless record.char.to_s.empty? && record.tile.to_i == 0
      list = PokeAccess.ivar(record.ev, :@list)
      return nil unless list.is_a?(Array)
      direct = list.any? { |c| c.code == 314 || c.code == 117 }
      return nil unless direct || PokeAccess::Locator.script_calls(list).any? { |script| script =~ PokeAccess::EventPages::HEAL_SCRIPT }
      return nil if PokeAccess::World::Mechanics.piece_of(record.ev)
      return nil unless PokeAccess::Routes::Effects.fires_on_arrival?(record.ev)
      directions = [2, 4, 6, 8].select do |direction|
        outcome = PokeAccess::EventPages.outcome(record.ev, direction, [record.x, record.y])
        outcome && outcome.heals && !outcome.unknown && !outcome.battle && !outcome.transfer &&
          !outcome.maybe_transfer && outcome.move.nil?
      end
      directions.empty? ? nil : directions
    end

    # Failed optional meaning reads leave the ordinary locator and sound classifiers available.
    def self.directions(event)
      record = PokeAccess::World::Events.record_of(event)
      record && PokeAccess::World::Events.facet(record, :healing_zone)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    def self.event?(event); !directions(event).nil?; end

    # All eligible floor goals: an unrestricted zone itself, or each real approach to a directional zone.
    def self.targets
      PokeAccess::World::Events.records.map do |record|
        next [] if PokeAccess::Locator.hidden?(record.ev)
        dirs = directions(record.ev)
        next [] unless dirs
        name = PokeAccess::Locator.target_name(record.ev)
        if dirs.length == 4
          [target(record.x, record.y, name, record.id, 0)]
        else
          dirs.map do |direction|
            delta = PokeAccess::DIR_DELTA[direction]
            x = record.x - delta[0]; y = record.y - delta[1]
            next nil unless $game_map.valid?(x, y)
            side = { 2 => :healing_south, 4 => :healing_west, 6 => :healing_east, 8 => :healing_north }[10 - direction]
            label = PokeAccess::I18n.t(:loc_healing_approach, :name => name, :direction => PokeAccess::I18n.t(side))
            target(x, y, label, record.id, direction)
          end.compact
        end
      end.flatten
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # A floor goal keeps its source event and final manual direction as its stable identity.
    def self.target(x, y, name, id, direction)
      PokeAccess::Locator::SurfaceTarget.new(x, y, name, :healing_zone, [id, direction])
    end

    def self.target?(value)
      value.is_a?(PokeAccess::Locator::SurfaceTarget) && value.key == :healing_zone
    end

    # Optional entry advice; the essential zone name and approach direction remain when help is off.
    def self.instruction(value)
      return nil unless PokeAccess::Config.read_help && target?(value)
      direction = value.ref[1]
      direction == 0 ? nil : PokeAccess::I18n.t(:healing_enter, :direction => direction_name(direction))
    end

    def self.direction_name(direction)
      PokeAccess::I18n.t({ 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }[direction])
    end
  end
end

PokeAccess::World::Events.facet_provider(:healing_zone) { |record| PokeAccess::HealingZones.inspect_record(record) }
PokeAccess::Locator.register_rule(:name) do |event|
  PokeAccess::I18n.t(:loc_healing_zone) if PokeAccess::HealingZones.event?(event)
end
PokeAccess::Locator.register_rule(:mark) { |target| PokeAccess::HealingZones.instruction(target) }
