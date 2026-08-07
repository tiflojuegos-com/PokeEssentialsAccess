# Quest journal (Modern Quest System + UI, Window_Quest). Its list lives in @quests as the plugin's own
# quest objects, and the name is not in them: the entry carries an id that $quest_data resolves.
#
# Not the plugin plugins/easy_questing.rb covers, which is Marin's Questlog. Two quest systems, two readers.
#
# Two marks the list draws instead of writing: a story quest is bold, and an unopened one carries a badge.
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

    # A page of the detail view. Its cursor is a local inside a blocking loop, so the read point is the draw
    # method for each page.
    #
    # Every $quest_data getter takes the quest ID, never the quest object: getName does const_get on what it
    # is given, and a Quest has no to_str.
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

    # Page one: the overview, plus what the current stage asks and where.
    def self.description_lines(quest, id)
      stage = (quest.stage rescue nil)
      [($quest_data.getQuestDescription(id) rescue nil),
       ($quest_data.getStageDescription(id, stage) rescue nil),
       shown(($quest_data.getStageLocation(id, stage) rescue nil))]
    end

    # Page two: progress, giver, where and when it started, and the reward.
    #
    # The reward is asked for the same way the screen asks, because it prints "???" while the quest runs.
    # Place and time are labelled as the screen labels them, and the time uses the plugin's own strftime.
    def self.other_lines(quest, id)
      total = ($quest_data.getMaxStagesForQuest(id) rescue nil)
      stage = (quest.stage rescue nil)
      lines = []
      lines.push(PokeAccess::I18n.t(:quest_stage, :n => stage, :tot => total)) if stage && total
      lines.push(PokeAccess::I18n.t(:quest_giver, :who => shown(($quest_data.getQuestGiver(id) rescue nil))))
      lines.push(PokeAccess::I18n.t(:quest_where, :where => shown((quest.location rescue nil))))
      when_at = (quest.time.strftime("%B %d %Y %H:%M") rescue nil)
      lines.push(PokeAccess::I18n.t(:quest_when, :when => when_at)) if when_at && !when_at.to_s.empty?
      lines.push(PokeAccess::I18n.t(:quest_reward, :what => reward(id)))
      lines
    end

    # What the screen puts on a blank field. The data stores the literal string "nil" for an unset giver or
    # location and the plugin paints "???" instead.
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

    # The tab the journal is on (Active, Completed or Side). Only a heading painted to a bitmap says which.
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

# swapQuestType runs on every tab change and pins the cursor back to 0, so the generic list reader's key is
# unchanged from the second swap on. Clearing its slot is what makes the list speak again: category first,
# then the quest it landed on.
PokeAccess::Hooks.after_hook("QuestList_Scene", :swapQuestType, :optional => true) do |scene, _r, _a|
  PokeAccess::QuestUI.category(scene)
  PokeAccess::Cursor.reset(PokeAccess.sprite(scene, "itemlist"), :cmd_focus)
end

# pbStartScene paints the category itself; swapQuestType only runs after a LEFT or RIGHT.
PokeAccess::Hooks.after_hook("QuestList_Scene", :pbStartScene, :optional => true) do |scene, _r, _a|
  PokeAccess::QuestUI.category(scene)
end

# The two pages of the detail view: each draw method runs when its page comes up, which is the page change.
PokeAccess::Hooks.after_hook("QuestList_Scene", :drawQuestDesc, :optional => true) do |_s, _r, args|
  PokeAccess::QuestUI.detail(args[0], :description)
end
PokeAccess::Hooks.after_hook("QuestList_Scene", :drawOtherInfo, :optional => true) do |_s, _r, args|
  PokeAccess::QuestUI.detail(args[0], :other)
end

# Volver del detalle a la lista. pbQuest ES el bucle del detalle, y al salir la escena reactiva la lista con
# el MISMO indice, asi que la clave del lector generico no cambia y la fila se queda muda: el jugador vuelve
# sin saber donde ha caido el cursor. Se envuelve en vez de engancharse despues para no anunciar nada desde
# dentro -- lo unico que se hace es soltar la ranura, y la lectura la da el lector de siempre.
PokeAccess::Hooks.around_hook("QuestList_Scene", :pbQuest, :optional => true) do |scene, nxt, _a|
  begin
    nxt.call
  ensure
    PokeAccess::Cursor.reset(PokeAccess.sprite(scene, "itemlist"), :cmd_focus)
  end
end
