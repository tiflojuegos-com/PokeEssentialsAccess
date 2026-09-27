module PokeAccess
  # Rejuvenation's edited copy of the Modern Quest System (read by plugins/quest_ui.rb): the overview takes the
  # stage, the "new" badge is the quest's notify flag, and the second page paints the expiration point and the
  # reward, shown even while the quest runs, but no date.
  module RejuvQuests
    # Page two as painted: progress, giver, where it was found, when it expires and the reward.
    # param ui the plugin's reader, whose shown words a blank field
    def self.other_lines(ui, quest, id)
      total = ($quest_data.getMaxStagesForQuest(id) rescue nil)
      stage = (quest.stage rescue nil)
      lines = []
      lines.push(PokeAccess::I18n.t(:quest_stage, :n => stage, :tot => total)) if stage && total
      lines.push(PokeAccess::I18n.t(:quest_giver, :who => ui.shown(($quest_data.getQuestGiver(id) rescue nil))))
      lines.push(PokeAccess::I18n.t(:quest_where, :where => ui.shown((quest.location rescue nil))))
      lines.push(PokeAccess::I18n.t(:rj_quest_expires, :when => expiration(id)))
      lines.push(PokeAccess::I18n.t(:quest_reward, :what => ui.shown(($quest_data.getQuestReward(id) rescue nil))))
      lines
    end

    # The expiration point, or the word for never where the data leaves it blank (the screen paints "Never!").
    def self.expiration(id)
      e = ($quest_data.getQuestTermination(id) rescue nil).to_s
      (e.empty? || e == "nil") ? PokeAccess::I18n.t(:rj_quest_never) : e
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  override("PokeAccess::QuestUI", :overview) do |_mod, _original, args|
    $quest_data.getQuestDescription(args[0], args[1])
  end

  override("PokeAccess::QuestUI", :new_badge?) do |_mod, _original, args|
    (args[0].notify rescue false) ? true : false
  end

  override("PokeAccess::QuestUI", :other_lines) do |mod, _original, args|
    PokeAccess::RejuvQuests.other_lines(mod, args[0], args[1])
  end
end
