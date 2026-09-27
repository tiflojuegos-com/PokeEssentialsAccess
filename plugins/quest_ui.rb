# Quest journal (Modern Quest System + UI, Window_Quest; not Marin's Questlog, read by easy_questing.rb): the
# list's quests, named through $quest_data by id, the category tab and the two detail pages.
module PokeAccess
  module QuestUI
    # The focused quest: its name, and from the quest reading's medium level the marks the list draws for a story
    # quest (bold) and a new one (badge); the info key keeps the whole row.
    def self.text(win, i)
      quests = win.instance_variable_get(:@quests)
      return nil unless quests.is_a?(Array) && i >= 0 && i < quests.length
      q = quests[i]
      return nil if q.nil?
      nm = ($quest_data.getName(q.id) rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      parts = [[PokeAccess.clean(nm.to_s), :brief]]
      parts.push([PokeAccess::I18n.t(:quest_story), :medium]) if (q.story rescue false)
      parts.push([PokeAccess::I18n.t(:quest_new), :medium]) if new_badge?(q)
      PokeAccess::Verbosity.info_line(:quest, parts)
    rescue StandardError
      nil
    end

    # Whether the row carries the "new" badge: the quest's own flag, the plugin's test. A game whose copy
    # draws it on fewer rows narrows this from its profile.
    def self.new_badge?(q)
      (q.new rescue false) ? true : false
    end

    # Speaks a detail page on its draw. Every $quest_data getter takes the quest id, never the Quest object,
    # which getName's const_get cannot take.
    def self.detail(quest, page)
      id = (quest.id rescue nil)
      return if id.nil?
      nm = ($quest_data.getName(id) rescue nil)
      return if nm.nil? || nm.to_s.empty?
      parts = [PokeAccess.clean(nm.to_s)]
      (page == :other ? other_lines(quest, id) : description_lines(quest, id)).each do |line|
        t = PokeAccess.clean(line.to_s)
        parts.push(t) unless t.empty? || t == "nil"
      end
      PokeAccess.speak(parts.join(". "), true)
    rescue StandardError
      nil
    end

    # Page one: the overview, plus what the current stage asks and where, each after the label the page paints before
    # it (Overview, Task, Location).
    def self.description_lines(quest, id)
      stage = (quest.stage rescue nil)
      [labeled(:quest_overview, (overview(id, stage) rescue nil)),
       labeled(:quest_task, ($quest_data.getStageDescription(id, stage) rescue nil)),
       PokeAccess::I18n.t(:quest_location, :text => shown(($quest_data.getStageLocation(id, stage) rescue nil)))]
    end

    # A field after its label, or nil for a blank one.
    def self.labeled(key, v)
      t = PokeAccess.clean(v.to_s)
      (t.empty? || t == "nil") ? nil : PokeAccess::I18n.t(key, :text => t)
    end

    # The quest's overview, which the plugin keeps per quest. A game that edits it to follow the stage
    # redefines this from its profile.
    def self.overview(id, _stage)
      $quest_data.getQuestDescription(id)
    end

    # Page two: progress, giver, where it started, the time (the plugin's strftime) under the label the page gives it,
    # and the reward, hidden while the quest runs as on screen.
    def self.other_lines(quest, id)
      total = ($quest_data.getMaxStagesForQuest(id) rescue nil)
      stage = (quest.stage rescue nil)
      lines = []
      lines.push(PokeAccess::I18n.t(:quest_stage, :n => stage, :tot => total)) if stage && total
      lines.push(PokeAccess::I18n.t(:quest_giver, :who => shown(($quest_data.getQuestGiver(id) rescue nil))))
      lines.push(PokeAccess::I18n.t(:quest_where, :where => shown((quest.location rescue nil))))
      when_at = (quest.time.strftime("%B %d %Y %H:%M") rescue nil)
      lines.push(PokeAccess::I18n.t(time_key(id), :when => when_at)) if when_at && !when_at.to_s.empty?
      lines.push(PokeAccess::I18n.t(:quest_reward, :what => reward(id)))
      lines
    end

    # The key of the time's label, as drawOtherInfo picks it: start for an active quest, completion for a completed
    # one, failure otherwise.
    def self.time_key(id)
      return :quest_time_start if (getActiveQuests.include?(id) rescue false)
      return :quest_time_done if (getCompletedQuests.include?(id) rescue false)
      :quest_time_failed
    end

    # What the screen puts on a blank field. The data stores the literal string "nil" for an unset giver or
    # location and the plugin paints "???" instead, said as a word since a screen reader drops the question marks.
    def self.shown(v)
      s = v.to_s
      (s.empty? || s == "nil") ? PokeAccess::I18n.t(:quest_unset) : s
    end

    def self.reward(id)
      r = ($quest_data.getQuestReward(id) rescue nil)
      active = (getActiveQuests.include?(id) rescue false)
      return PokeAccess::I18n.t(:quest_hidden) if active || r.nil? || r.to_s.empty? || r.to_s == "nil"
      r
    end

    # The tab the journal is on, as the heading painted to a bitmap says it ("Active tasks"): the painted row that holds
    # the tab's name, else the name alone.
    # param pairs what the heading's draw painted, as PaintCapture.sample gives it
    def self.category(scene, pairs = nil)
      names = PokeAccess.ivar(scene, :@quests_text)
      i = PokeAccess.ivar(scene, :@current_quest)
      return unless names.is_a?(Array) && i.is_a?(Integer) && names[i]
      label = PokeAccess.clean(names[i].to_s)
      return if label.empty?
      heading = Array(pairs).map { |r| PokeAccess.clean(r[0].to_s) }.find { |t| t.include?(label) }
      PokeAccess.speak(heading || label, true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Menus.def_extractor("Window_Quest") { |win, i| PokeAccess::QuestUI.text(win, i) }

# A tab change: the category as its heading paints it, then its first quest, the list's slot cleared as the cursor
# goes back to 0.
PokeAccess::Hooks.around_hook("QuestList_Scene", :swapQuestType, :optional => true) do |scene, nxt, _a|
  r = nil
  pairs = PokeAccess::PaintCapture.sample { r = nxt.call }
  PokeAccess::QuestUI.category(scene, pairs)
  PokeAccess::Cursor.reset(PokeAccess.sprite(scene, "itemlist"), :cmd_focus)
  r
end

# pbStartScene paints the category itself; swapQuestType only runs after a LEFT or RIGHT. Before and after, not
# around: its fade-in updates the list, whose reader must stay quiet under the guard so the heading comes first.
PokeAccess::Hooks.before_hook("QuestList_Scene", :pbStartScene, :optional => true) do |_s, _a|
  PokeAccess::PaintCapture.arm(:quest_head)
end
PokeAccess::Hooks.after_hook("QuestList_Scene", :pbStartScene, :optional => true) do |scene, _r, _a|
  PokeAccess::QuestUI.category(scene, PokeAccess::PaintCapture.take_pairs(:quest_head))
end

# The two pages of the detail view: each draw method runs when its page comes up, which is the page change.
PokeAccess::Hooks.after_hook("QuestList_Scene", :drawQuestDesc, :optional => true) do |_s, _r, args|
  PokeAccess::QuestUI.detail(args[0], :description)
end
PokeAccess::Hooks.after_hook("QuestList_Scene", :drawOtherInfo, :optional => true) do |_s, _r, args|
  PokeAccess::QuestUI.detail(args[0], :other)
end

# Back from the detail (pbQuest, its loop) to the list on the same index: the list's slot is released so the
# generic reader says the row again.
PokeAccess::Hooks.around_hook("QuestList_Scene", :pbQuest, :optional => true) do |scene, nxt, _a|
  begin
    nxt.call
  ensure
    PokeAccess::Cursor.reset(PokeAccess.sprite(scene, "itemlist"), :cmd_focus)
  end
end

PokeAccess::Verbosity.define_reading(:quest, :vb_quest, :vbh_quest)
