# Quest journal (the Modern Quest System + UI plugin, Window_Quest). Another Window_DrawableCommand whose
# list is somewhere the generic reader does not look -- @quests, holding the plugin's own quest objects --
# so the window read as nothing. The name is not in there either: the entry carries an id and the name is
# resolved through $quest_data.
#
# NOT the same plugin as the one plugins/easy_questing.rb covers: that is Marin's Questlog, a different quest
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

    # A page of the detail view. Its cursor is a LOCAL inside a blocking loop, so nothing can poll it -- but
    # the two page bodies are drawn by two named methods that each receive the quest, and those firing IS the
    # page change.
    #
    # Every $quest_data getter takes the quest ID, never the quest object: getName does const_get on what it
    # is handed, and a Quest has no to_str, so passing the object raises TypeError on the first line and the
    # whole detail view said nothing at all.
    def self.detail(quest, page)
      id = (quest.id rescue nil)
      return if id.nil?
      nm = ($quest_data.getName(id) rescue nil)
      return if nm.nil? || nm.to_s.empty?
      parts = [PokeAccess.clean(nm.to_s)]
      (page == :other ? other_lines(quest, id) : description_lines(quest, id)).each do |line|
        t = PokeAccess.clean(line.to_s).to_s.strip
        parts.push(t) unless t.empty? || t == "nil"
      end
      PokeAccess.speak(parts.join(". "), true)
    rescue StandardError
      nil
    end

    # Page one: the overview and, more usefully, what the current stage asks and where. Those last two are
    # the only actionable text on the screen.
    def self.description_lines(quest, id)
      stage = (quest.stage rescue nil)
      [($quest_data.getQuestDescription(id) rescue nil),
       ($quest_data.getStageDescription(id, stage) rescue nil),
       ($quest_data.getStageLocation(id, stage) rescue nil)]
    end

    # Page two: progress, who gave it, where and when it started, and the reward. The reward is hidden while
    # the quest is still running -- the screen prints "???" -- so it is asked for the same way rather than
    # read straight out of the data, which would hand the player a spoiler the screen is withholding.
    def self.other_lines(quest, id)
      total = ($quest_data.getMaxStagesForQuest(id) rescue nil)
      stage = (quest.stage rescue nil)
      lines = []
      lines.push(PokeAccess::I18n.t(:quest_stage, :n => stage, :tot => total)) if stage && total
      lines.push(PokeAccess::I18n.t(:quest_giver, :who => ($quest_data.getQuestGiver(id) rescue nil)))
      lines.push((quest.location rescue nil))
      lines.push(PokeAccess::I18n.t(:quest_reward, :what => reward(id)))
      lines
    end

    def self.reward(id)
      r = ($quest_data.getQuestReward(id) rescue nil)
      active = (getActiveQuests.include?(id) rescue false)
      return PokeAccess::I18n.t(:quest_hidden) if active || r.nil? || r.to_s.empty? || r.to_s == "nil"
      r
    end

    # The tab the journal is on. LEFT and RIGHT swap between Active, Completed and Side, and the only thing
    # that says which you are on is a heading painted to a bitmap -- so the list re-read after a swap gave a
    # different set of quests with no clue that the category had changed under it.
    def self.category(scene)
      names = PokeAccess.ivar(scene, :@quests_text)
      i = PokeAccess.ivar(scene, :@current_quest)
      return unless names.is_a?(Array) && i.is_a?(Integer) && names[i]
      label = PokeAccess.clean(names[i].to_s).to_s.strip
      return if label.empty?
      PokeAccess.speak(label, true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Menus.def_extractor("Window_Quest") { |win, i| PokeAccess::QuestUI.text(win, i) }

# swapQuestType runs on every tab change and nowhere else. It pins the list cursor back to 0, so the generic
# list reader's key -- [index, pocket] -- is unchanged from the second swap onwards and the list stays mute
# even though every quest in it just changed. Clearing that reader's slot is what makes it speak again:
# category first, then the quest it landed on, which is the order the player needs.
PokeAccess::Hooks.after_hook("QuestList_Scene", :swapQuestType, :optional => true) do |scene, _r, _a|
  PokeAccess::QuestUI.category(scene)
  PokeAccess::Cursor.reset(PokeAccess.sprite(scene, "itemlist"), :cmd_focus)
end

# The two pages of the detail view. Each draw method is called once when its page comes up -- on opening, and
# on every LEFT/RIGHT between the two -- so hooking them reads the page without needing the loop's own cursor.
PokeAccess::Hooks.after_hook("QuestList_Scene", :drawQuestDesc, :optional => true) do |_s, _r, args|
  PokeAccess::QuestUI.detail(args[0], :description)
end
PokeAccess::Hooks.after_hook("QuestList_Scene", :drawOtherInfo, :optional => true) do |_s, _r, args|
  PokeAccess::QuestUI.detail(args[0], :other)
end
