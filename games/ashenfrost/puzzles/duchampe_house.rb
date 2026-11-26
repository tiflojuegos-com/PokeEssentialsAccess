# The Duchampe Residence of case two. Hall (map 109): eight statues with no sprite (events 21 to 28), of which only EV21
# to EV24 take a press, in the order variable 39 counts; the book (EV39) gives their places, 7-3-1-6. Bedroom (map 110):
# smells lead to floorboards (EV21) and the safe (EV13). Pump Room (map 114): three spots, any gives the clue.
module PokeAccess
  module AshenDuchampe
    HALL = 109
    BEDROOM = 110
    # The hall's statues in reading order, the place each is numbered by.
    STATUES = [23, 25, 22, 26, 27, 24, 21, 28]
    # The statues that take a press, in the order variable 39 counts them.
    ORDER = [21, 22, 23, 24]
    FAKES = STATUES - ORDER
    BOOK = 39
    SMELLS = [17, 18, 19, 20, 21, 23, 24]
    # The smells that are photos on the shelf while Sylvester looks.
    PHOTOS = [17, 23, 24]
    TRAIL_END = 21
    SAFE = 13
    PUMP_ROOM = 114
    # The Pump Room's three spots by the water: any gives the fight's clue, and all three are spent with it.
    PUMP_SPOTS = [3, 4, 5]

    # How many statues have taken their press.
    def self.pressed; $game_variables[39].to_i; end

    # A statue's number, its place in reading order.
    def self.number(id); STATUES.index(id) + 1; end

    # Whether the statues take presses: the backyard seen (switch 67) and the ladder still hidden.
    def self.statues_live?; $game_switches[67] && pressed < ORDER.length ? true : false; end

    # Whether Truffles is out sniffing.
    def self.sniffing?; $game_switches[71] ? true : false; end

    # A self switch of a bedroom event.
    def self.self_on?(id, letter); $game_self_switches[[BEDROOM, id, letter]] ? true : false; end

    # Whether the floorboards Truffles pointed at wait to be lifted.
    def self.floorboards?; self_on?(TRAIL_END, "A") && !self_on?(TRAIL_END, "B"); end

    # Whether the safe is out and still shut.
    def self.safe_shut?; self_on?(SAFE, "A") && !self_on?(SAFE, "B"); end

    # A smell spot's name: a smell while Truffles sniffs, the floorboards at the trail's end, a photo for Sylvester;
    # else nil.
    def self.trail_label(ev)
      return :afa_smell if sniffing?
      return :afa_floorboards if ev.id == TRAIL_END && floorboards?
      PHOTOS.include?(ev.id) ? :afa_photo : nil
    end

    # Whether a smell spot is part of the trail now: a smell, or the floorboards it leads to.
    def self.on_trail?(ev); [:afa_smell, :afa_floorboards].include?(trail_label(ev)); end

    # Whether the Pump Room's clue has been found.
    def self.pump_clue?; $game_self_switches[[PUMP_ROOM, PUMP_SPOTS[0], "A"]] ? true : false; end
  end
end

PokeAccess::Game.define("ashenfrost") do
  house = PokeAccess::AshenDuchampe
  mechanic(:state, house::HALL, :part => :afa_statues) do
    auto
    hall = at(28, 42, 4, 12)
    name house::STATUES, :afa_statue, :numbered => true, :when => lambda { |_ev| house.statues_live? }
    name house::BOOK, :afa_book, :when => false
    hide house::FAKES, :assist => true
    house::ORDER.each_with_index do |id, k|
      phase lambda { PokeAccess::Puzzles.assist? && house.statues_live? && house.pressed == k && hall.call },
            :hint => [:afa_statue_next, { :n => house.number(id) }], :hidden => right_way(id)
    end
    solved(nil, :quiet => true) { house.pressed >= house::ORDER.length }
  end

  mechanic(:state, house::BEDROOM, :part => :afa_safe) do
    auto
    name house::SMELLS, lambda { |ev| house.trail_label(ev) }, :when => lambda { |ev| house.on_trail?(ev) }
    name house::SAFE, :afa_safe, :when => lambda { |_ev| house.safe_shut? }
    hide house::SMELLS - [house::TRAIL_END], :assist => true, :when => lambda { |_ev| house.sniffing? }
    phase lambda { PokeAccess::Puzzles.assist? && house.sniffing? },
          :hint => :afa_smell_hint, :hidden => right_way(house::TRAIL_END)
    phase lambda { PokeAccess::Puzzles.assist? && house.floorboards? },
          :hint => :afa_floorboards_hint, :hidden => right_way(house::TRAIL_END)
    phase lambda { PokeAccess::Puzzles.assist? && house.safe_shut? },
          :hint => :afa_safe_hint, :hidden => right_way(house::SAFE)
    solved(nil, :quiet => true) { house.self_on?(house::SAFE, "B") }
  end

  mechanic(:state, house::PUMP_ROOM, :part => :afa_pump) do
    auto
    name house::PUMP_SPOTS, :afa_pump_spot, :when => lambda { |_ev| !house.pump_clue? }
    hide house::PUMP_SPOTS[1..-1], :assist => true, :when => lambda { |_ev| !house.pump_clue? }
  end
end
