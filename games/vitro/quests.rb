# Vitro's quest detail (0273_Quest_UI) paints the overview and the task on its first page, and the stage's place, who gave it
# and the reward, in sight while the quest runs, on its second; it paints neither the stage count, nor where it began, nor the
# time. Each page is said as this copy paints it, through the game's translations.
module PokeAccess
  module VitroQuests
    # What the block reads of a quest, as the screen paints it; nil when it cannot be read.
    def self.painted
      _INTL(yield.to_s)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  override("PokeAccess::QuestUI", :description_lines) do |mod, _original, args|
    quest, id = args
    [mod.labeled(:quest_overview, PokeAccess::VitroQuests.painted { $quest_data.getQuestDescription(id) }),
     mod.labeled(:quest_task, PokeAccess::VitroQuests.painted { $quest_data.getStageDescription(id, quest.stage) })]
  end
  override("PokeAccess::QuestUI", :other_lines) do |mod, _original, args|
    quest, id = args
    place = PokeAccess::VitroQuests.painted { $quest_data.getStageLocation(id, quest.stage) }
    [PokeAccess::I18n.t(:quest_location, :text => mod.shown(place)),
     PokeAccess::I18n.t(:quest_giver, :who => mod.shown(PokeAccess::VitroQuests.painted { $quest_data.getQuestGiver(id) })),
     PokeAccess::I18n.t(:quest_reward, :what => mod.shown(PokeAccess::VitroQuests.painted { $quest_data.getQuestReward(id) }))]
  end
end
