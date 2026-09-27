# Soulstones 2's two edits to the Modern Quest System (plugins/quest_ui.rb): the overview takes the stage
# (getQuestDescription(quest, stage)), and completed quests have no "new" badge.
PokeAccess::Game.define("soulstones2") do
  override("PokeAccess::QuestUI", :overview) do |_mod, _original, args|
    $quest_data.getQuestDescription(args[0], args[1])
  end

  override("PokeAccess::QuestUI", :new_badge?) do |_mod, original, args|
    original.call && !(getCompletedQuests.include?((args[0].id rescue nil)) rescue false)
  end
end
