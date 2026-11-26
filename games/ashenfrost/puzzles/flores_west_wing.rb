# The West Wing of the Flores Mansion (map 651, Case Fifteen): the piano (switch 260) and the library's Rotom (switch
# 261) open the safe door (EV57). The piano asks for ocarina song six (EV4, SongGreen; assist_answers.rb says it). The
# five books (EV1 to EV5) show sheets by colour; the Rotom (variable 229) turns up six times (EV51 to EV56).
module PokeAccess
  module AshenFlores
    MAP = 651
    PIANO_DONE = 260
    LIBRARY_DONE = 261
    ROTOM = 229
    BOOKS = { 1 => :afh_book_red, 2 => :afh_book_orange, 3 => :afh_book_yellow, 4 => :afh_book_green, 5 => :afh_book_blue }
    # How to face each Rotom, by the value of 229 it answers at.
    SIDES = { 0 => :afh_rotom_start, 1 => :afh_rotom_any, 2 => :afh_rotom_from_right, 3 => :afh_rotom_from_below,
              4 => :afh_rotom_from_above, 5 => :afh_rotom_from_below, 6 => :afh_rotom_any }

    # Whether the library is still to finish.
    def self.library_left?
      !$game_switches[LIBRARY_DONE]
    end

    # The assist's line for the Rotom the library waits for now.
    def self.rotom_hint
      SIDES[$game_variables[ROTOM].to_i]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  flores = PokeAccess::AshenFlores
  mechanic(:state, flores::MAP, :part => :piano_library) do
    auto
    flores::BOOKS.each { |id, key| name id, key }
    phase lambda { PokeAccess::Puzzles.assist? && flores.library_left? && flores.rotom_hint }, :quiet => true,
          :hint => lambda { flores.rotom_hint }
    solved(nil, :quiet => true) { $game_switches[flores::PIANO_DONE] && !flores.library_left? }
  end
end
