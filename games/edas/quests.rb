# Edas' quest log (Easy Questing, re-skinned in 0133_PScreen_QuestInterface): the detail has one page, its "pager" sprite
# being a mere separator, so no page is said; and the colour a quest's name is painted in, said from medium.
module PokeAccess
  module EdasQuests
    # The colours that mark a quest, as pbColor gives them, and the key each is said with; white marks nothing.
    MARKS = [[[18, 235, 170], :edas_quest_blue], [[255, 115, 115], :edas_quest_red], [[197, 252, 70], :edas_quest_green]]

    # The spoken mark of a quest's colour, or nil.
    def self.mark(quest)
      c = (quest.color rescue nil)
      rgb = [(c.red rescue nil), (c.green rescue nil), (c.blue rescue nil)].map { |v| v.to_i }
      row = MARKS.find { |m, _key| m == rgb }
      row ? PokeAccess::I18n.t(row[1]) : nil
    end
  end
end

PokeAccess::Game.define("edas") do
  override("PokeAccess::Quests", :page_mark) { |_mod, _original, _args| nil }
  override("PokeAccess::Quests", :color_mark) { |_mod, _original, args| PokeAccess::EdasQuests.mark(args[0]) }
end
