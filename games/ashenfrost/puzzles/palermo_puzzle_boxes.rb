# The three puzzle boxes of Palermo's House (Case Six), each giving the safe's code: the kitchen's (map 364, EV19), a
# tile puzzle; the study's (map 366, EV18), a lock on seven books (EV11 to EV17) kept by the colours seven facts (EV4 to
# EV10) say to trust; the piano room's (map 367, EV9), opened by one of three sheets (EV5 to EV7) played on EV15.
module PokeAccess
  module AshenPuzzleBoxes
    KITCHEN = 364
    STUDY = 366
    PIANO_ROOM = 367
    # Each box of a map and the self switch its last page waits for, set as it gives its paper.
    BOXES = { KITCHEN => 19, STUDY => 18, PIANO_ROOM => 9 }
    # The study's books, by event, under their colours, and its facts likewise: EV10 is named "Indigo" but checks
    # violet.
    BOOKS = { 11 => :aff_book_red, 12 => :aff_book_orange, 13 => :aff_book_yellow, 14 => :aff_book_green, 15 => :aff_book_blue,
              16 => :aff_book_indigo, 17 => :aff_book_violet }
    FACTS = { 4 => :aff_fact_red, 5 => :aff_fact_orange, 6 => :aff_fact_yellow, 7 => :aff_fact_green, 8 => :aff_fact_blue,
              9 => :aff_fact_indigo, 10 => :aff_fact_violet }
    # The piano room's books of sheet music, by event.
    SHEETS = { 5 => :aff_sheet_red, 6 => :aff_sheet_blue, 7 => :aff_sheet_yellow }
    PIANO = 15

    # Whether a map's box has given its paper.
    def self.opened?(map)
      $game_self_switches[[map, BOXES[map], "B"]] ? true : false
    end

    # Whether the piano has been played right, which opens the room's box (EV15's self switch A).
    def self.played?
      $game_self_switches[[PIANO_ROOM, PIANO, "A"]] ? true : false
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  boxes = PokeAccess::AshenPuzzleBoxes

  boxes::BOXES.each do |map, box|
    mechanic(:state, map, :part => :aff_puzzle_box) do
      auto
      name box, :aff_puzzle_box, :when => lambda { |_ev| !boxes.opened?(map) }
      solved(nil, :quiet => true) { boxes.opened?(map) }
    end
  end

  mechanic(:state, boxes::STUDY, :part => :aff_study) do
    auto
    unsolved = lambda { |_ev| !boxes.opened?(boxes::STUDY) }
    boxes::BOOKS.dup.merge!(boxes::FACTS).each { |id, label| name id, label, :when => unsolved }
    hint :aff_study_hint
    active { PokeAccess::Puzzles.assist? && !boxes.opened?(boxes::STUDY) }
    solved(nil, :quiet => true) { boxes.opened?(boxes::STUDY) }
  end

  mechanic(:state, boxes::PIANO_ROOM, :part => :aff_piano) do
    auto
    boxes::SHEETS.each { |id, label| name id, label, :when => lambda { |_ev| !boxes.played? } }
    hint :aff_piano_hint
    active { PokeAccess::Puzzles.assist? && !boxes.played? }
    solved(nil, :quiet => true) { boxes.played? }
  end
end
