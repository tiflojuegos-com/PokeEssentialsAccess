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
    def self.category(scene)
      modes = PokeAccess.ivar(scene, :@modes)
      idx = PokeAccess.ivar(scene, :@main_menu_index)
      return unless modes.is_a?(Array) && idx.is_a?(Integer) && idx >= 0 && idx < modes.length
      title = ((modes[idx].title rescue nil) || (modes[idx].name rescue nil)).to_s
      return if title.empty?
      PokeAccess::Cursor.announce(scene, :if2_qcat, idx, true) do
        PokeAccess::I18n.t(:if2_pokenav, :name => title, :n => idx + 1, :tot => modes.length)
      end
    rescue StandardError
      nil
    end

    # The focused quest of the list screen.
    def self.quest(scene)
      list = PokeAccess.ivar(scene, :@filtered_quests)
      idx = PokeAccess.ivar(scene, :@quest_list_menu_index)
      return unless list.is_a?(Array) && idx.is_a?(Integer) && idx >= 0 && idx < list.length
      line = quest_line(list[idx])
      return if line.nil?
      PokeAccess::Cursor.announce(scene, :if2_quest, idx, true) do
        PokeAccess::I18n.t(:if2_pokenav, :name => line, :n => idx + 1, :tot => list.length)
      end
    rescue StandardError
      nil
    end

    # The detail screen: the full brief (description, who gave it and where), read once on opening.
    def self.detail(scene)
      list = PokeAccess.ivar(scene, :@filtered_quests)
      idx = PokeAccess.ivar(scene, :@quest_list_menu_index)
      return unless list.is_a?(Array) && idx.is_a?(Integer) && idx >= 0 && idx < list.length
      q = list[idx]
      parts = [quest_line(q)]
      [(q.desc rescue nil), (q.npc rescue nil), (q.location rescue nil)].each do |v|
        parts.push(PokeAccess.clean(v.to_s)) if v && !v.to_s.strip.empty?
      end
      t = parts.compact.reject { |s| s.to_s.empty? }.join(". ")
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
  after("Questlog", :show_quest_detail) { |s, _r, _a| PokeAccess::IF2Quests.detail(s) }
end
