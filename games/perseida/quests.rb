# Perseida's quest detail (0237_Quest_UI) moves the location to the second page and paints neither the stage count nor the
# time, and its reward stays in sight while the quest runs: each page is said as this copy paints it. The list paints some
# quests in a colour of their own, passed by the map events (colorQuest), and its key bar under them.
module PokeAccess
  module PerseidaQuests
    # The colours events give a quest, as colorQuest names them, and the key each is said with.
    COLORS = [["cyan", :perseida_quest_cyan], ["orange", :perseida_quest_orange]]

    # The rows of the key bar, as pbStartScene paints them.
    BAR = /\A(?:FLECHAS|Q\/W):/

    # The spoken mark of a quest's colour, or nil.
    def self.mark(quest)
      row = COLORS.find { |name, _key| quest.color == colorQuest(name) }
      row ? PokeAccess::I18n.t(row[1]) : nil
    end

    # The key bar, said after the heading while key hints are said; only the screen's opening paints it.
    # param pairs what the heading's draw painted, as PaintCapture.take_pairs gives it
    def self.bar(pairs)
      keys = Array(pairs).map { |r| PokeAccess.clean(r[0].to_s) }.select { |t| t =~ BAR }
      return unless PokeAccess::Verbosity.hints? && !keys.empty?
      PokeAccess.speak(keys.map { |t| PokeAccess::KeyHints.localize(t) }.join(". "), false)
    end
  end
end

PokeAccess::Game.define("perseida") do
  override("PokeAccess::QuestUI", :color_mark) { |_mod, _original, args| PokeAccess::PerseidaQuests.mark(args[0]) }
  override("PokeAccess::QuestUI", :category) do |_mod, original, args|
    original.call
    PokeAccess::PerseidaQuests.bar(args[1])
  end
  override("PokeAccess::QuestUI", :description_lines) do |mod, _original, args|
    quest, id = args
    [mod.labeled(:quest_overview, ($quest_data.getQuestDescription(id) rescue nil)),
     mod.labeled(:quest_task, ($quest_data.getStageDescription(id, (quest.stage rescue nil)) rescue nil))]
  end
  override("PokeAccess::QuestUI", :other_lines) do |mod, _original, args|
    quest, id = args
    place = ($quest_data.getStageLocation(id, (quest.stage rescue nil)) rescue nil)
    [PokeAccess::I18n.t(:quest_location, :text => mod.shown(place)),
     PokeAccess::I18n.t(:quest_giver, :who => mod.shown(($quest_data.getQuestGiver(id) rescue nil))),
     PokeAccess::I18n.t(:quest_where, :where => mod.shown((quest.location rescue nil))),
     PokeAccess::I18n.t(:quest_reward, :what => mod.shown(($quest_data.getQuestReward(id) rescue nil)))]
  end
end
