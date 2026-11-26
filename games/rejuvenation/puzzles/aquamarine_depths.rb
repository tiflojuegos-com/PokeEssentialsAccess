# The sealed door of Aquamarine Depths (map 323): five black stones and Braixen, each a tile away per use, to push onto
# six floor marks. The tile before the door (event 52, variable 96 at 63) checks them and breaks the door (switch 1437)
# with every mark covered: stone 61 counts on the X alone, Braixen on any but the O. Leaving south (event 31) resets it.
module PokeAccess
  module RejuvAquamarine
    # [x, y] => the mark's symbol, as drawn.
    MARKS = { [48, 65] => :rj_aqua_triangle, [50, 61] => "X", [58, 66] => "O", [44, 60] => "V", [58, 59] => "E",
              [62, 62] => "Z" }
    # [event, start, goal, legs as [direction, pushes], its mark's symbol], in the order they are placed; the X and
    # the E sit on islets and need Surf.
    PIECES = [
      [61, [49, 59], [50, 61], [[2, 2], [6, 1]], "X"],
      [26, [56, 61], [58, 59], [[6, 1], [8, 2], [6, 1]], "E"],
      [53, [60, 62], [62, 62], [[6, 2]], "Z"],
      [54, [59, 74], [58, 66], [[8, 8], [4, 1]], "O"],
      [55, [41, 63], [44, 60], [[8, 3], [6, 3]], "V"],
      [50, [48, 69], [48, 65], [[8, 4]], :rj_aqua_triangle]
    ]
    BRAIXEN = 50

    # True once the door is broken.
    def self.open?
      $game_switches[1437] ? true : false
    end

    # True while the door checks the marks and is still shut.
    def self.live?
      $game_variables[96].to_i >= 63 && !open?
    end

    # How many marks a piece stands on, whichever piece.
    def self.covered
      spots = PIECES.map { |p| PokeAccess::RejuvPushLegs.at(p[0]) }
      MARKS.keys.select { |m| spots.include?(m) }.length
    end

    # True while the assist is on, the door is shut and this piece is off its mark.
    def self.placing?(piece)
      PokeAccess::Puzzles.assist? && live? && PokeAccess::RejuvPushLegs.at(piece[0]) != piece[2]
    end

    # True once every piece stands on its own mark.
    def self.placed?
      PIECES.all? { |p| PokeAccess::RejuvPushLegs.at(p[0]) == p[2] }
    end

    # A piece's label: Braixen, or a black stone by where it stands now.
    def self.label(id)
      return :rj_aqua_braixen if id == BRAIXEN
      lambda do
        x, y = PokeAccess::RejuvPushLegs.at(id)
        [:rj_aqua_stone, { :x => x, :y => y }]
      end
    end

    # A mark's spoken symbol.
    def self.symbol(sym)
      sym.is_a?(Symbol) ? PokeAccess::I18n.t(sym) : sym
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  aqua = PokeAccess::RejuvAquamarine
  mechanic(:state, 323, :part => :marks) do
    auto
    aqua::MARKS.each do |(x, y), sym|
      spot :at => [x, y], :label => lambda { [:rj_aqua_mark, { :sym => aqua.symbol(sym) }] }, :onto => true,
           :when => lambda { aqua.live? }
    end
    name 52, :rj_aqua_door_tile, :when => lambda { |_ev| aqua.live? }
    count :rj_aqua_covered, :value => lambda { aqua.covered }, :of => 6, :reset => false
    arrival_hint lambda { aqua.live? ? :rj_aqua_rule : nil }
    aqua::PIECES.each do |pc|
      piece = pc[0, 4] + [aqua.label(pc[0]), lambda { [:rj_aqua_mark, { :sym => aqua.symbol(pc[4]) }] }]
      opts = { :hint => lambda { PokeAccess::RejuvPushLegs.hint(piece, :rj_aqua_reset_hint) } }
      unless pc[0] == aqua::BRAIXEN
        opts[:track] = { :event => pc[0], :label => piece[4], :goal => [pc[2][0], pc[2][1], pc[2][0], pc[2][1]],
                         :goal_label => piece[5] }
      end
      phase lambda { aqua.placing?(pc) }, opts
    end
    phase lambda { PokeAccess::Puzzles.assist? && aqua.live? && aqua.placed? },
          :hint => :rj_aqua_door_hint, :hidden => right_way(52)
    phase lambda { aqua.live? }
    solved { aqua.open? }
  end
end
