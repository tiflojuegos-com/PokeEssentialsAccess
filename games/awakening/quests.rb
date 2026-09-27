# Awakening's quest log (Easy Questing): the colour a quest's name is painted in, said from medium.
module PokeAccess
  module AwakeningQuests
    # The painted colours that mark a quest, as pbColor gives them (its :RED of 272 is clamped to 255), and the key
    # each is said with; the rest, white among them, mark nothing.
    MARKS = [[[255, 160, 50], :awk_quest_gold], [[255, 67, 67], :awk_quest_red], [[139, 247, 215], :awk_quest_blue]]

    # The spoken mark of a quest's colour, or nil.
    def self.mark(q)
      c = (q.color rescue nil)
      return nil if c.nil?
      rgb = [(c.red rescue nil), (c.green rescue nil), (c.blue rescue nil)].map { |v| [v.to_i, 255].min }
      row = MARKS.find { |m, _k| m == rgb }
      row ? PokeAccess::I18n.t(row[1]) : nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  override("PokeAccess::Quests", :color_mark) { |_mod, _original, args| PokeAccess::AwakeningQuests.mark(args[0]) }
end
