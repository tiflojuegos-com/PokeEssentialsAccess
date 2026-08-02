# Quest journal (the Modern Quest System + UI plugin, Window_Quest). Another Window_DrawableCommand whose
# list is somewhere the generic reader does not look -- @quests, holding the plugin's own quest objects --
# so the window read as nothing. The name is not in there either: the entry carries an id and the name is
# resolved through $quest_data.
#
# NOT the same plugin as the one core/field/quests.rb covers: that is Marin's Questlog, a different quest
# system with different classes. Two quest plugins, two readers.
#
# Beyond the name, two things the screen shows visually and a reader has to say out loud: a story quest is
# painted in bold, and a quest the player has not opened yet gets a "new" badge in the corner.
module PokeAccess
  module QuestUI
    # The focused quest: its name, and the two marks the list draws instead of writing.
    def self.text(win, i)
      quests = win.instance_variable_get(:@quests)
      return nil unless quests.is_a?(Array) && i >= 0 && i < quests.length
      q = quests[i]
      return nil if q.nil?
      nm = ($quest_data.getName(q.id) rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      parts = [PokeAccess.clean(nm.to_s)]
      parts.push(PokeAccess::I18n.t(:quest_story)) if (q.story rescue false)
      parts.push(PokeAccess::I18n.t(:quest_new)) if (q.new rescue false)
      parts.join(", ")
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Menus.def_extractor("Window_Quest") { |win, i| PokeAccess::QuestUI.text(win, i) }
