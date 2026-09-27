# Drago2308's Quest Marker (Awakening, Realidea): a picture over each event whose live page opens with a
# "quest_marker <picture>" comment, said after the event's name in the locator with the word its game gives it.
module PokeAccess
  module QuestMarker
    # The i18n key a marker picture is said with, or nil: the same names carry different pictures in different games,
    # so each game's profile overrides this, and a picture it does not describe goes unsaid.
    def self.word(_picture); nil; end

    # The marker picture an event's live page asks for, or nil when its first command is no marker comment.
    def self.picture(ev)
      list = PokeAccess.ivar(ev, :@list)
      first = list.is_a?(Array) ? list[0] : nil
      return nil unless first && (first.code rescue nil) == 108
      words = (first.parameters.first rescue nil).to_s.split
      words.first == "quest_marker" ? words[1] : nil
    rescue StandardError
      nil
    end

    # The spoken word for an event's marker, or nil.
    def self.mark(ev)
      pic = picture(ev)
      key = pic ? word(pic) : nil
      key ? PokeAccess::I18n.t(key) : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.override(PokeAccess::Locator, :name_marks, :tag => "quest_marker") do |_mod, original, args|
  mark = PokeAccess::QuestMarker.mark(args[0])
  mark ? (original.call || []) | [mark] : original.call
end
