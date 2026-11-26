# Vanhanen Castle's chess rooms (maps 313, 316, 317, 318): white pieces (sprites chess1 to chess6; black ones end in b)
# are pushed one square on columns 6 to 13, rows 8 to 15 (a1 at 6,15); bishops diagonally, pawns up, crowned by a menu
# (variable 154). Spriteless events at the north door check the mate (variable 150 at 29, 33, 36, 39).
module PokeAccess
  module RebornChess
    COLUMNS = "abcdefgh"
    TYPES = { "1" => "pawn", "2" => "bishop", "3" => "rook", "4" => "knight", "5" => "queen", "6" => "king" }
    SOLVED = { 313 => 29, 316 => 33, 317 => 36, 318 => 39 }
    DOORS = { 313 => [43, 44], 316 => [49, 54], 317 => [57, 59], 318 => [51, 60] }
    START = {
      313 => { 9 => [6, 15], 42 => [10, 15] },
      316 => { 39 => [7, 14], 40 => [11, 14], 38 => [6, 15] },
      317 => { 53 => [13, 14], 52 => [12, 14], 48 => [12, 15] },
      318 => { 49 => [7, 13], 53 => [11, 13], 54 => [11, 15], 57 => [7, 15] }
    }
    PLAN = {
      313 => [[9, [6, 8]], [42, [12, 15]], [42, [12, 10]]],
      316 => [[39, [7, 11]], [39, [10, 11]], [40, [8, 11], [8, 4]], [38, [6, 11]], [38, [7, 11]], [38, [7, 8]],
              [38, [8, 8]]],
      317 => [[53, [13, 13], :pawn], [52, [12, 8], :knight], [52, [12, 12]], [52, [6, 12]], [52, [6, 10]],
              [48, [12, 12]], [48, [7, 12]], [48, [7, 10]]],
      318 => [[49, [7, 8], :bishop], [49, [10, 11], [6, 2]], [53, [7, 13]], [53, [7, 8]], [53, [10, 8]], [53, [10, 9]],
              [54, [9, 13], [4, 8]], [57, [7, 13]]]
    }
    DIR_WORDS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }

    # The square of (x,y), as "a1"; nil off the board.
    def self.square(x, y)
      return nil if x < 6 || x > 13 || y < 8 || y > 15
      "#{COLUMNS[x - 6, 1]}#{16 - y}"
    end

    # A piece's name with its square, by its sprite; nil for an event that shows no piece.
    def self.label(ev)
      return nil unless ev.character_name.to_s =~ /\Achess([1-6])(b?)\z/
      sq = square(ev.x, ev.y)
      sq && [:"rba_vc_#{$2 == 'b' ? 'black' : 'white'}_#{TYPES[$1]}", { :square => sq }]
    end

    # Where piece id stands now.
    def self.at(id)
      ev = $game_map.events[id]
      ev && [ev.x, ev.y]
    end

    # True when cur lies on the straight or diagonal line from a to b, b left out.
    def self.on_way?(cur, a, b)
      steps = [(b[0] - a[0]).abs, (b[1] - a[1]).abs].max
      ux = b[0] <=> a[0]
      uy = b[1] <=> a[1]
      (0...steps).any? { |t| cur == [a[0] + t * ux, a[1] + t * uy] }
    end

    # The plan's move under way, by the pieces' squares: its index, :done with every move made, or nil off the plan
    # (leaving the room puts the pieces back).
    def self.progress(map)
      plan = PLAN[map]
      states = [START[map].dup]
      plan.each { |id, goal| s = states.last.dup; s[id] = goal; states.push(s) }
      return :done if states.last.all? { |id, xy| at(id) == xy }
      (plan.length - 1).downto(0) do |k|
        id, goal = plan[k]
        before = states[k]
        next unless before.all? { |pid, xy| pid == id || at(pid) == xy }
        return k if on_way?(at(id), before[id], goal)
      end
      nil
    end

    # With the assist, the next move of the room's mate, or what to do off the plan.
    def self.hint(map)
      k = progress(map)
      return :rba_vc_hint_reset if k.nil?
      return :rba_vc_hint_check if k == :done
      id, goal, how = PLAN[map][k]
      vars = { :from => square(*at(id)), :to => square(*goal) }
      if how.is_a?(Array)
        return [:rba_vc_hint_diagonal, vars.dup.merge!(:face => PokeAccess::I18n.t(DIR_WORDS[how[0]]),
                                                       :key => PokeAccess::I18n.t(DIR_WORDS[how[1]]))]
      end
      return [:rba_vc_hint_pawn, vars] if how == :pawn
      return [:rba_vc_hint_crown, vars.dup.merge!(:into => PokeAccess::I18n.t(:"rba_vc_#{how}"))] if how
      [:rba_vc_hint_push, vars]
    end
  end
end

PokeAccess::Game.define("reborn") do
  chess = PokeAccess::RebornChess
  chess::SOLVED.each do |map, goal|
    mechanic(:state, map) do
      auto
      name(/\Achess[1-6]b?\z/, lambda { |ev| chess.label(ev) })
      name chess::DOORS[map], :rba_vc_door, :grouped => true
      arrival_hint :rba_vc_rule, :once => true
      hint lambda { chess.hint(map) }
      active { $game_variables[150].to_i < goal }
      solved { $game_variables[150].to_i >= goal }
    end
  end
end
