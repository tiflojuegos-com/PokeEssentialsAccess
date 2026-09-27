# Event Indicators (its current release): the marker it floats over an event whose active page carries an "Event
# Indicator" comment, said after the event's name by the locator while it shows. Only the quest markers are named.
module PokeAccess
  module EventIndicators
    # The words for a marker type the plugin draws with its quest graphics ("quest", "questsimple"...), else nil.
    def self.type_key(type)
      t = type.to_s
      (t =~ /\Aquest/i && t !~ /\Aquestion/i) ? :evind_quest : nil
    end

    # The marker showing over one of the map's own events, as words: nil when it has none, it is hidden or disposed,
    # its type is not a quest one, or the target is no map event. The markers live in the map's spriteset, one per
    # event id.
    def self.mark(ev)
      eid = PokeAccess::Locator.event_id_of(ev)
      return nil unless eid && ($game_map.events[eid] rescue nil).equal?(ev)
      set = ($scene.spriteset((ev.map_id rescue 0)) rescue nil)
      sprites = (set.event_indicator_sprites rescue nil)
      return nil unless sprites.is_a?(Array)
      s = sprites[eid]
      return nil if s.nil? || (s.disposed? rescue true) || !(s.visible rescue false)
      key = type_key((s.type rescue nil))
      key ? PokeAccess::I18n.t(key) : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.override(PokeAccess::Locator, :name_marks, :tag => "event_indicators") do |_m, original, args|
  original.call + [PokeAccess::EventIndicators.mark(args[0])].compact
end
