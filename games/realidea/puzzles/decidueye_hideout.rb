# The cave of the Decidueye gang (map 36): the boss (event 28) asks for three passwords in turn, each written in Spanish
# to passCheck. His self switches A, B and C say which he asks for, and switches 125 to 127 that each has been given; the
# third (127) ends it: no rule on arriving, nothing on the info key.
module PokeAccess
  module RealideaDecidueye
    MAP = 36
    BOSS = 28
    MEMBERS = [19, 20, 23, 25]
    PASSWORDS = [["A", "Mapa"], ["B", "Secreto"], ["C", "Muerte"]]
    DONE = 127

    # The password the boss asks for now, or nil before he asks for any and once all are given.
    def self.asked
      return nil if $game_switches[DONE]
      due = PASSWORDS.select { |letter, _word| $game_self_switches[[MAP, BOSS, letter]] }
      due.empty? ? nil : due[due.length - 1][1]
    end

    # What the puzzle assist says as the boss is spoken to.
    def self.answer
      word = asked
      word ? [:puzzle_answer, { :a => word }] : ""
    end
  end
end

PokeAccess::Game.define("realidea") do
  gang = PokeAccess::RealideaDecidueye
  mechanic(:state, gang::MAP) do
    auto
    name gang::BOSS, :rea_decidueye_boss
    name gang::MEMBERS, :rea_decidueye_member
    count :rea_decidueye_passwords, :switches => [125, 126, 127]
    on_use gang::BOSS, lambda { gang.answer }, :assist => true
    right_choice gang::BOSS, :takes => { :self => "A" }
    arrival_hint :rea_decidueye_rule
    solved { $game_switches[gang::DONE] }
  end
end
