# Event Indicators in Keishou's release (000_Settings.rb, 001_Script.rb), older than plugins/event_indicators.rb's: the
# marker it floats over an event whose active page carries an "Event Indicator" comment, said after the event's name by
# the locator while it shows. The quest markers and the Day Care's egg, which this game adds, are named.
module PokeAccess
  module KeishouQuestMarks
    # The marker showing over one of the map's own events, as words, or nil; the map's spriteset holds one per event id.
    def self.mark(ev)
      eid = PokeAccess::Locator.event_id_of(ev)
      return nil unless eid && ($game_map.events[eid] rescue nil).equal?(ev)
      sprites = ($scene.spriteset((ev.map_id rescue 0)).event_indicator_sprites rescue nil)
      s = sprites.is_a?(Array) ? sprites[eid] : nil
      return nil if s.nil? || (s.disposed? rescue true) || !(s.visible rescue false)
      word((s.type rescue nil).to_s)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The words for a marker's type, or nil for one that names nothing.
    def self.word(type)
      return PokeAccess::I18n.t(:evind_quest) if type =~ /\Aquest/i && type !~ /\Aquestion/i
      type == "egg" ? PokeAccess::I18n.t(:evind_egg) : nil
    end
  end
end

PokeAccess::Locator.register_rule(:mark) { |t| PokeAccess::KeishouQuestMarks.mark(t) }
