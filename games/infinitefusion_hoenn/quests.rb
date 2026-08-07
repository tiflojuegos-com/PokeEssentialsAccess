# Hoenn rewrote the quest log from scratch (Questlog, 052_InfiniteFusion/Gameplay/Quests/QuestsLogUI.rb), so
# the core Questlog reader does not fit: the ivars are new (@main_menu_index over the category buttons,
# @quest_list_menu_index over @filtered_quests, @current_mode) and there are now three screens
# (SCENE_MAIN / SCENE_LIST / SCENE_DETAIL). Everything is drawn into the scene's own bitmaps.
#
# The navigation methods are private (the class declares `private` before them), which the hook engine
# preserves, so hooking them is safe and keeps the game's own visibility.
module PokeAccess
  module IF2Quests
    # The spoken line for a quest row, in the same shape the core quest reader uses for other games, so a
    # player hears quests phrased identically everywhere.
    def self.quest_line(q)
      return nil if q.nil?
      name = (q.name rescue nil).to_s
      return nil if name.empty?
      st = PokeAccess::I18n.t((q.completed rescue false) ? :qu_status_done : :qu_status_pending)
      PokeAccess::I18n.t(:qu_line, :name => name, :status => st)
    end

    # Category buttons of the main screen (main quests / side quests / completed).
    #
    # Silent while the detail screen is up: opening the log straight on a quest paints the main screen first
    # and only then jumps, so the category is a button the player never sees.
    def self.category(scene)
      return if PokeAccess.ivar(scene, :@scene) == 2
      modes = PokeAccess.ivar(scene, :@modes)
      idx = PokeAccess.ivar(scene, :@main_menu_index)
      return unless modes.is_a?(Array) && idx.is_a?(Integer) && idx >= 0 && idx < modes.length
      title = ((modes[idx].title rescue nil) || (modes[idx].name rescue nil)).to_s
      return if title.empty?
      PokeAccess::Cursor.announce(scene, :if2_qcat, idx, true) do
        PokeAccess::I18n.t(:list_entry, :name => title, :n => idx + 1, :tot => modes.length)
      end
    rescue StandardError
      nil
    end

    # The focused quest of the list screen, or the category's own empty message when it has none: an empty
    # category still shows that line, so entering one is not a silent transition.
    #
    # The CATEGORY is in the dedup key. Questlog runs its whole loop inside initialize, so the holder lives
    # as long as the screen does and every category opens with the cursor on row zero: on the index alone
    # the second category of a visit reads as unchanged and enters silent, which a player takes for empty.
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
      line = quest_line(list[idx])
      return if line.nil?
      cat = PokeAccess.ivar(scene, :@main_menu_index)
      PokeAccess::Cursor.announce(scene, :if2_quest, [cat, idx], true) do
        PokeAccess::I18n.t(:list_entry, :name => line, :n => idx + 1, :tot => list.length)
      end
    rescue StandardError
      nil
    end

    # The detail screen: the full brief (description, who gave it and where), read once on opening.
    # param quest the quest the screen was handed, when it came that way
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
      PokeAccess.speak(t, true) unless t.empty?
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  # switch_button is the ONLY thing that moves @main_menu_index, and nothing calls it on entry (initialize
  # just sets it to 0), so the main screen opened without saying which category was focused. draw_main_text
  # is what paints it, which is the same moment the player would see it.
  after("Questlog", :draw_main_text) { |s, _r, _a| PokeAccess::IF2Quests.category(s) }
  after("Questlog", :switch_button) { |s, _r, _a| PokeAccess::IF2Quests.category(s) }
  after("Questlog", :move_selection) { |s, _r, _a| PokeAccess::IF2Quests.quest(s) }
  after("Questlog", :show_quest_list) { |s, _r, _a| PokeAccess::IF2Quests.quest(s) }
  # Coming back from the list repaints the categories through redraw_main_screen, which is not the method
  # that painted them the first time, and lands on the same index -- so the slot is cleared to place the
  # player again.
  after("Questlog", :redraw_main_screen) do |s, _r, _a|
    PokeAccess::Cursor.reset(s, :if2_qcat)
    PokeAccess::IF2Quests.category(s)
  end
  # draw_quest_details is the one point both routes into the brief share: the list's own confirm and the
  # jump the map's "open this quest" takes, which never touches show_quest_detail at all.
  after("Questlog", :draw_quest_details) { |s, _r, a| PokeAccess::IF2Quests.detail(s, a[0]) }
end
