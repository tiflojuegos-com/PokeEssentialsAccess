# Lab Manager confrontation (Serenity Marine Facility, map 107, EV12, Case Three): his first and fourth pages (switch
# 69) ask for evidence (self switch A); the fifth asks a name (passCheck "Her name.") and three pieces, the third right
# one setting self switch B. The assist names evidence by the case file; the name is assist_answers.rb's.
module PokeAccess
  module AshenEvidence
    # The game's names of pieces of evidence, by their internal names, joined; an unknown one keeps its internal name.
    def self.names(list)
      data = (::Evidence.compiledData rescue nil) || {}
      list.map { |sym| ((data[sym] || {})[:Name] || sym).to_s }.join(", ")
    end
  end

  module AshenLabManager
    MAP = 107
    MANAGER = 12
    MET = 69
    ASIDE = 70
    FIRST = [:TESTGHOST]
    ROUNDS = [:TESTGHOST, :CLUEBOX, :TESTSCOT]

    # A self switch of the Lab Manager.
    def self.self_on?(letter)
      $game_self_switches[[MAP, MANAGER, letter]] ? true : false
    end

    # What the assist says as the Lab Manager is spoken to: the evidence his first and fourth pages ask for, and the
    # three rounds of his fifth after the name; nothing on his other pages (switch 70, self switches B and C).
    def self.answer
      return nil if self_on?("B") || self_on?("C")
      return nil if !$game_switches[MET] && ($game_switches[ASIDE] || self_on?("A"))
      return [:afe_lab_first, { :list => AshenEvidence.names(FIRST) }] unless self_on?("A")
      [:afe_lab_answer, { :list => AshenEvidence.names(ROUNDS) }]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  lab = PokeAccess::AshenLabManager
  mechanic(:state, lab::MAP, :part => :afe_lab) do
    auto
    on_use lab::MANAGER, lambda { |_ev| lab.answer }, :assist => true
  end
end
