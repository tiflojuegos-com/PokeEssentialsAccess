# Infinite Fusion's quest log paints each quest's name in its branch's colour and keeps the branch where Marin's plugin
# keeps a giver ("Hotel Quests"): the row says it from medium, between the name and the status.
Suite.define("infinite fusion: a quest's row says its branch, the colour its name is painted in") do
  qs = PokeAccess::Quests
  meta = (class << qs; self; end)
  meta.send(:alias_method, :if_spec_quest_row, :quest_row)
  quest = Struct.new(:name, :npc, :completed)
  begin
    load File.expand_path("../../../games/infinitefusion/quest_branches.rb", File.dirname(__FILE__))
    pending = PokeAccess::I18n.t(:qu_status_pending)
    rows = vb_levels { qs.quest_row(quest.new("Mushroom Gathering", "Hotel Quests", false)) }
    eq "brief: the name", rows[0], "Mushroom Gathering"
    eq "medium: its branch and whether it is done", rows[1], "Mushroom Gathering, Hotel Quests, #{pending}"
    eq "a quest with no branch reads as before", qs.quest_row(quest.new("Lost Medicine", nil, false)),
       "Lost Medicine, #{pending}"
  ensure
    meta.send(:alias_method, :quest_row, :if_spec_quest_row)
    meta.send(:remove_method, :if_spec_quest_row)
  end
end
