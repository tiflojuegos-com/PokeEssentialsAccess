# Vitro's Bug Contest comparison (the second PokeBattle_BugContestBattle#pbStorePokemon in 0182_PBattle_BugContest): catching a
# second Pokemon paints both on a window of its own, name, level and hit points, where the stock method calls the help window core
# reads. What it paints is said queued, a sentence per Pokemon, as the game asks whether to switch, and the info key keeps it until
# the question is answered.
module PokeAccess
  module VitroBugContest
    TAG = :vitro_bug_contest
    # The height the new Pokemon's rows start at on that window.
    NEW_ROWS = 88

    # The window's rows as painted, a sentence per Pokemon.
    def self.line(rows)
      older, newer = rows.partition { |row| row[3].is_a?(Numeric) && row[3] < NEW_ROWS }
      PokeAccess.sentences([older, newer].map { |part| PokeAccess::PaintCapture.lines(part).join(" ") }.reject { |text| text.empty? })
    end

    # Says, as the question comes, what the comparison painted since the catch; nothing where no comparison is running.
    def self.asked
      return unless PokeAccess::PaintCapture.pending?(TAG)
      text = line(PokeAccess::PaintCapture.take_pairs(TAG))
      return if text.empty?
      PokeAccess.speak(text, false)
      PokeAccess::Info.set_info(:text, text)
    end
  end
end

PokeAccess::Game.define("vitro") do
  around("PokeBattle_BugContestBattle", :pbStorePokemon, :hook_container => true) do |_battle, nxt, _a|
    PokeAccess::PaintCapture.arm(PokeAccess::VitroBugContest::TAG)
    begin
      nxt.call
    ensure
      PokeAccess::PaintCapture.take_pairs(PokeAccess::VitroBugContest::TAG)
      PokeAccess::Info.clear_text
    end
  end
  before("PokeBattle_Battle", :pbDisplayConfirm) { |_battle, _a| PokeAccess::VitroBugContest.asked }
end
