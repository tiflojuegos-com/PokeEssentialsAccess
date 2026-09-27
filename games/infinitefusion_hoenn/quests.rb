# Hoenn's own quest log (Questlog): the categories (@main_menu_index), a category's list (@quest_list_menu_index
# over @filtered_quests) and a quest's brief, all drawn into the scene's bitmaps.
module PokeAccess
  module IF2Quests
    # The kind each quest type's name colour marks wherever a quest's name is painted: main green, Magma dark red and
    # Aqua light purple; field quests are painted white, and Hoenn defines no other type.
    TYPE_KEYS = { :MAIN_QUEST => :qmp_main, :MAGMA_QUEST => :if2_qt_magma, :AQUA_QUEST => :if2_qt_aqua }

    # The kind a quest's name colour marks, as a quest-reading part from medium; nil for a quest painted plain.
    def self.kind_part(q)
      kind = TYPE_KEYS[(q.type rescue nil)]
      kind ? [PokeAccess::I18n.t(kind), :medium] : nil
    end

    # A quest's name and, from medium, its state and the kind its colour marks, as quest-reading parts; nil for a
    # quest without a name.
    def self.quest_parts(q)
      return nil if q.nil?
      name = (q.name rescue nil).to_s
      return nil if name.empty?
      st = PokeAccess::I18n.t((q.completed rescue false) ? :qu_status_done : :qu_status_pending)
      [[name, :brief], [st, :medium], kind_part(q)].compact
    end

    # A category button as the log paints it: its button text and how many quests it holds.
    def self.category_label(mode)
      n = (mode.filter_quests($Trainer.quests).size rescue nil)
      text = (mode.button_text rescue nil) || (mode.title rescue nil) || (mode.name rescue nil)
      return nil if text.nil? || text.to_s.empty?
      PokeAccess.clean(n ? _INTL("{1}: {2}", text, n) : text.to_s)
    end

    # The log's title and, while key hints are said and the log can switch to the map, its hint for it.
    def self.title(scene)
      t = PokeAccess.clean(_INTL("Quest Log"))
      return t unless (scene.send(:can_switch_mode?) rescue false)
      PokeAccess::Verbosity.with_hint(t, PokeAccess.clean(_INTL("L/R : MAP")))
    end

    # A quest's whole line, in the core quest reader's shape (qu_line).
    def self.quest_line(q)
      parts = quest_parts(q)
      parts ? PokeAccess::I18n.t(:qu_line, :name => parts[0][0], :status => parts[1][0]) : nil
    end

    # The focused category button of the main screen; silent while the detail screen is up (@scene 2), which a
    # log opened on a quest reaches after painting the main screen.
    def self.category(scene)
      return if PokeAccess.ivar(scene, :@scene) == 2
      modes = PokeAccess.ivar(scene, :@modes)
      idx = PokeAccess.ivar(scene, :@main_menu_index)
      return unless modes.is_a?(Array) && idx.is_a?(Integer) && idx >= 0 && idx < modes.length
      label = category_label(modes[idx])
      return if label.nil?
      PokeAccess::Cursor.announce(scene, :if2_qcat, idx, true, false) do
        PokeAccess::Verbosity.list_entry(label, idx + 1, modes.length)
      end
    rescue StandardError
      nil
    end

    # The log as it opens: its title and hint, queued before the focused category (a quest opened from the map
    # interrupts both with its brief).
    def self.opened(scene)
      PokeAccess.speak(title(scene), false)
    end

    # The focused quest of the list at the quest reading's level, or the category's empty message; keyed on the
    # category too, since each one opens on row zero; the info key keeps the whole row.
    def self.quest(scene)
      list = PokeAccess.ivar(scene, :@filtered_quests)
      idx = PokeAccess.ivar(scene, :@quest_list_menu_index)
      return unless list.is_a?(Array)
      if list.empty?
        msg = (PokeAccess.ivar(scene, :@current_mode).empty_message rescue nil)
        PokeAccess.speak(PokeAccess.clean(msg.to_s), true) if msg && !msg.to_s.strip.empty?
        return
      end
      return unless idx.is_a?(Integer) && idx >= 0 && idx < list.length
      parts = quest_parts(list[idx])
      return if parts.nil?
      cat = PokeAccess.ivar(scene, :@main_menu_index)
      PokeAccess::Cursor.announce(scene, :if2_quest, [cat, idx], true) do
        PokeAccess::Verbosity.list_entry(PokeAccess::Verbosity.info_line(:quest, parts), idx + 1, list.length)
      end
    rescue StandardError
      nil
    end

    # The detail screen's brief (quest line, description, giver and place), of the quest handed in or focused.
    def self.detail(scene, quest = nil)
      q = quest
      if q.nil?
        list = PokeAccess.ivar(scene, :@filtered_quests)
        idx = PokeAccess.ivar(scene, :@quest_list_menu_index)
        return unless list.is_a?(Array) && idx.is_a?(Integer) && idx >= 0 && idx < list.length
        q = list[idx]
      end
      parts = [quest_line(q)]
      [(q.desc rescue nil), (q.npc rescue nil), (q.location rescue nil)].each do |v|
        parts.push(PokeAccess.clean(v.to_s)) if v && !v.to_s.strip.empty?
      end
      t = PokeAccess::Util.join_parts(parts)
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  # draw_main_text for the title and the category focused on entry, switch_button for each move.
  after("Questlog", :draw_main_text) do |s, _r, _a|
    PokeAccess::IF2Quests.opened(s)
    PokeAccess::IF2Quests.category(s)
  end
  after("Questlog", :switch_button) { |s, _r, _a| PokeAccess::IF2Quests.category(s) }
  after("Questlog", :move_selection) { |s, _r, _a| PokeAccess::IF2Quests.quest(s) }
  # The list slot is reset on every open: reopening a category lands on the row already recorded.
  after("Questlog", :show_quest_list) do |s, _r, _a|
    PokeAccess::Cursor.reset(s, :if2_quest)
    PokeAccess::IF2Quests.quest(s)
  end
  # Back from the list, redraw_main_screen repaints the same category: the slot is reset so it is said again.
  after("Questlog", :redraw_main_screen) do |s, _r, _a|
    PokeAccess::Cursor.reset(s, :if2_qcat)
    PokeAccess::IF2Quests.category(s)
  end
  # draw_quest_details is shared by both routes into the brief: the list's confirm and the map's jump to a quest.
  after("Questlog", :draw_quest_details) { |s, _r, a| PokeAccess::IF2Quests.detail(s, a[0]) }
end

# The map's quest side panel (QuestMapPopup, its own loop over @quests): the game's "{1} Quests" header, then
# each row with, from medium, the kind its name's colour marks.
PokeAccess::Game.define("infinitefusion_hoenn") do
  before("QuestMapPopup", :run) do |s, _a|
    loc = PokeAccess.ivar(s, :@location_name)
    t = ((_INTL("{1} Quests", loc) rescue nil) || loc).to_s
    PokeAccess.speak_clean(t, false)
  end
  # blocks-on-purpose: run is the panel's loop, and its rows leave the info key when it is over.
  after("QuestMapPopup", :run) { |_s, _r, _a| PokeAccess::Info.clear_text }
end

PokeAccess::SceneWatcher.reader("QuestMapPopup", :run, :qmp_row) do |s|
  quests = PokeAccess.ivar(s, :@quests)
  idx = PokeAccess.ivar(s, :@index)
  if quests.is_a?(Array) && idx.is_a?(Integer) && quests[idx]
    [idx, lambda do
      q = quests[idx]
      parts = [[PokeAccess.clean((q.name rescue "").to_s), :brief], PokeAccess::IF2Quests.kind_part(q)].compact
      PokeAccess::Verbosity.list_entry(PokeAccess::Verbosity.info_line(:quest, parts), idx + 1, quests.length)
    end]
  else
    nil
  end
end

PokeAccess::Verbosity.define_reading(:quest, :vb_quest, :vbh_quest)
