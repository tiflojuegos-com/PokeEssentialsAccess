# Glass Workstation's psychic glass blocks (maps 736 and 738, the rooms of the Master Ball and of TM29): with Espeon
# following (switch 947) a piece waits for a key and its block's page moves it two tiles that way when the others let it
# and not towards the player. Each block's place is a variable (427 to 431, 422 to 426); the plan is data keyed by them.
module PokeAccess
  module RebornGlassEspeon
    ESPEON = 947
    CLEARED = 953
    OPPOSITE = { 2 => 8, 8 => 2, 4 => 6, 6 => 4 }
    DIR_WORD = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }
    MOVED = { 2 => :rbrc_glass_down, 4 => :rbrc_glass_left, 6 => :rbrc_glass_right, 8 => :rbrc_glass_up }
    LOWER = [[12, 38], [12, 39], [13, 38], [13, 39], [14, 38], [14, 39]]

    # Map => its room: the blocks' variables, the pieces' name, the room's box [x0, y0, x1, y1], how the prize is told
    # taken, each variable's value => the way its block went, the states with no way left, and the plan: state => its
    # moves as [moves left, block, tile to stand on, facing, key, the tiles it is for (any, if none)].
    ROOMS = {
      736 => { :vars => [427, 428, 429, 430, 431], :name => /\AGB2F (\d)(Core|B)\z/, :room => [10, 33, 15, 41],
               :taken => lambda { $game_self_switches[[736, 31, "A"]] },
               :moved => [{ 1 => 8 }, { 1 => 4, 2 => 2 }, { 1 => 2 }, { 1 => 8 }, { 1 => 6 }],
               :stuck => ["0,2,1,0,0", "0,2,1,0,1", "1,2,1,0,1"],
               :plan => { "0,0,0,0,0" => [[6, 5, [12, 35], 8, 6]], "0,0,0,0,1" => [[5, 1, [12, 35], 4, 8]],
                          "0,0,1,0,0" => [[5, 5, [12, 35], 8, 6]], "0,0,1,0,1" => [[4, 1, [12, 35], 4, 8]],
                          "1,0,0,0,1" => [[4, 2, [12, 35], 2, 4]],
                          "1,0,1,0,1" => [[1, 4, [12, 39], 4, 8, LOWER], [3, 2, [12, 35], 2, 4]],
                          "1,1,0,0,1" => [[3, 3, [13, 37], 2, 2]], "1,1,1,0,1" => [[2, 2, [12, 38], 8, 6]] } },
      738 => { :vars => [422, 423, 424, 425, 426], :name => /\AGBS(\d)(Core|B)\z/, :room => [8, 11, 20, 16],
               :taken => lambda { $game_switches[1429] },
               :moved => [{ 1 => 4 }, { 1 => 4 }, { 1 => 4 }, { 1 => 4 }, { 1 => 4 }],
               :stuck => [],
               :plan => { "0,0,0,0,0" => [[5, 1, [14, 13], 2, 4]], "1,0,0,0,0" => [[4, 2, [15, 14], 8, 4]],
                          "1,1,0,0,0" => [[3, 3, [16, 13], 2, 4]], "1,1,1,0,0" => [[2, 4, [17, 14], 8, 4]],
                          "1,1,1,1,0" => [[1, 5, [18, 13], 2, 4]] } }
    }

    # The room of the map the player is on, or nil.
    def self.room
      $game_map && ROOMS[$game_map.map_id]
    end

    # The blocks' variables as the plan writes them, "0,0,1,0,1".
    def self.state(r)
      r[:vars].map { |v| $game_variables[v].to_i }.join(",")
    end

    # True while the player stands in the room's box.
    def self.inside?(r)
      x0, y0, x1, y1 = r[:room]
      px = $game_player.x
      py = $game_player.y
      px >= x0 && px <= x1 && py >= y0 && py <= y1
    end

    # True once the prize is taken or the blocks are gone.
    def self.done?(r)
      ($game_switches[CLEARED] || PokeAccess::World::Mechanics.truth(r[:taken])) ? true : false
    end

    # The move to make now, as the plan's entry, or nil once the way is open, off the plan or done.
    def self.step
      r = room
      return nil unless r && !done?(r)
      moves = r[:plan][state(r)]
      return nil unless moves
      at = [$game_player.x, $game_player.y]
      moves.find { |m| m[5].nil? || m[5].include?(at) }
    end

    # True when the blocks stand where no move opens the way again.
    def self.stuck?
      r = room
      r && !done?(r) && r[:stuck].include?(state(r)) ? true : false
    end

    # A block's number by its piece's event name, or nil.
    def self.block_of(ev)
      r = room
      m = r && ev.name.to_s.match(r[:name])
      m && m[1].to_i
    end

    # A piece's name: its block's.
    def self.label(ev)
      n = block_of(ev)
      n && PokeAccess::I18n.t(:rbrc_glass_block, :n => n)
    end

    # The tile the next move is made from, with the assist.
    def self.stand_at
      s = PokeAccess::Puzzles.assist? && step
      s && s[2]
    end

    # The next move in words, for its tile in the list.
    def self.spot_label
      s = step
      s && PokeAccess::I18n.t(:rbrc_glass_spot, :n => s[1], :dir => PokeAccess::I18n.t(DIR_WORD[s[4]]))
    end

    # With the assist, the info key's plan: the moves left and the next, from where; that no way is left; or nothing.
    def self.step_line
      i18n = PokeAccess::I18n
      return i18n.t(:rbrc_glass_stuck) if stuck?
      s = step
      return nil unless s
      opts = { :left => s[0], :n => s[1], :dir => i18n.t(DIR_WORD[s[4]]), :face => i18n.t(DIR_WORD[s[3]]) }
      dx = s[2][0] - $game_player.x
      dy = s[2][1] - $game_player.y
      return i18n.t(:rbrc_glass_step_here, opts) if dx == 0 && dy == 0
      opts[:where] = PokeAccess::Locator.dir_phrase(dx, dy)
      i18n.t(:rbrc_glass_step, opts)
    end

    # What using a piece says: with Espeon, that it waits for a direction, and with the assist the planned key when the
    # piece is of the planned block and the player faces it from the planned side.
    def self.use_line(ev)
      return nil unless $game_switches[ESPEON]
      i18n = PokeAccess::I18n
      s = PokeAccess::Puzzles.assist? && step
      if s && s[1] == block_of(ev) && $game_player.direction != OPPOSITE[s[4]]
        return i18n.t(:rbrc_glass_wait_key, :dir => i18n.t(DIR_WORD[s[4]]))
      end
      i18n.t(:rbrc_glass_wait)
    end

    # The rule, said on arriving inside the room.
    def self.rule
      r = room
      r && inside?(r) ? :rbrc_glass_rule : nil
    end
  end
end

PokeAccess::Game.define("reborn") do
  ge = PokeAccess::RebornGlassEspeon
  ge::ROOMS.each do |map, r|
    mechanic(:state, map, :part => :glass_espeon) do
      auto
      name r[:name], lambda { |ev| ge.label(ev) }, :when => lambda { |ev| ev.name.to_s =~ /Core\z/ }
      on_use r[:name], lambda { |ev| ge.use_line(ev) }
      r[:vars].each_with_index do |v, i|
        words = { 0 => :rbrc_glass_home }
        r[:moved][i].each { |value, dir| words[value] = ge::MOVED[dir] }
        watch :var => v, :label => [:rbrc_glass_block, { :n => i + 1 }], :words => words
      end
      spot :at => lambda { ge.stand_at }, :label => lambda { ge.spot_label }, :assist => true, :onto => true
      arrival_hint lambda { ge.rule }
      hint lambda { ge.step_line }
      active { ge.inside?(r) && !ge.done?(r) }
      solved(nil, :quiet => true) { ge.done?(r) }
    end
  end
end
