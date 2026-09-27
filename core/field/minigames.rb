module PokeAccess
  # The standard Essentials minigames: Voltorb Flip, Mining, Slot Machine, Duel and Tile Puzzle. Voltorb Flip's
  # @squares is a 5x5 grid, index row*5+col, each [x, y, value, flipped].
  module Minigames
    VF_W = 5

    # The spoken state of one Voltorb Flip cell: its value once flipped, else marked or hidden.
    def self.vf_cell(squares, marks, col, row)
      cell = (squares[row * VF_W + col] rescue nil)
      return "" unless cell.is_a?(Array)
      return (cell[2].to_i == 0 ? PokeAccess::I18n.t(:mg_voltorb) : cell[2].to_s) if cell[3]
      marked = (marks || []).any? { |m| m.is_a?(Array) && m[1] == col * 64 + 128 && m[2] == row * 64 }
      marked ? PokeAccess::I18n.t(:mg_marked) : PokeAccess::I18n.t(:mg_hidden)
    end

    # The coin sum and Voltorb count of a line of cells (the hint shown on the board edge).
    def self.vf_line(squares, idxs, label)
      sum, voltorbs = vf_totals(squares, idxs)
      PokeAccess::I18n.t(:mg_line, :label => label, :sum => sum, :voltorbs => voltorbs)
    end

    # [coin sum, Voltorb count] of a line of cells.
    def self.vf_totals(squares, idxs)
      sum = 0
      voltorbs = 0
      idxs.each do |i|
        v = (squares[i][2].to_i rescue 1)
        sum += v
        voltorbs += 1 if v == 0
      end
      [sum, voltorbs]
    end

    # Voices the Voltorb Flip cursor on change: position and cell, the row/column hint on entering a new one, the
    # mode when it toggles, the coins when they move; on arrival or a new board (new @squares), level and both hints.
    def self.voltorb_flip(scene)
      idx = scene.instance_variable_get(:@index)
      return unless idx.is_a?(Array)
      col = idx[0].to_i
      row = idx[1].to_i
      squares = scene.instance_variable_get(:@squares)
      marks = scene.instance_variable_get(:@marks)
      mode = (scene.instance_variable_get(:@cursor)[0][3] rescue 0).to_i
      cell = vf_cell(squares, marks, col, row)
      pts = (scene.instance_variable_get(:@points) rescue nil).to_i
      board = (squares.object_id rescue nil)
      sig = [col, row, cell, mode, pts, board]
      prev = scene.instance_variable_get(:@pa_vf)
      return if sig == prev
      scene.instance_variable_set(:@pa_vf, sig)
      prev = nil if prev && prev[5] != board
      parts = []
      parts << PokeAccess::I18n.t(:mg_level, :n => (scene.instance_variable_get(:@level) rescue 1).to_i) if prev.nil?
      parts << (mode == 0 ? PokeAccess::I18n.t(:mg_mode_normal) : PokeAccess::I18n.t(:mg_mode_mark)) if prev && prev[3] != mode
      parts << PokeAccess::I18n.t(:mg_coins, :n => pts) if prev && prev[4] != pts
      parts << PokeAccess::I18n.t(:mg_rowcol, :row => row + 1, :col => col + 1)
      parts << cell unless cell.empty?
      parts << vf_line(squares, (0...VF_W).map { |c| row * VF_W + c }, PokeAccess::I18n.t(:mg_row)) if prev.nil? || prev[1] != row
      parts << vf_line(squares, (0...VF_W).map { |r| r * VF_W + col }, PokeAccess::I18n.t(:mg_col)) if prev.nil? || prev[0] != col
      PokeAccess.speak(parts.join(", "), true, :menu)
      PokeAccess::Info.set_info(:text, vf_board(squares, marks))
    rescue StandardError
      nil
    end

    # The whole board for the info key: each row's five cards with its sum and Voltorbs, then each column's.
    def self.vf_board(squares, marks)
      out = []
      VF_W.times do |r|
        cells = (0...VF_W).map { |c| vf_cell(squares, marks, c, r) }
        sum, voltorbs = vf_totals(squares, (0...VF_W).map { |c| r * VF_W + c })
        out << PokeAccess::I18n.t(:mg_board_row, :n => r + 1, :cells => cells.join(", "), :sum => sum, :voltorbs => voltorbs)
      end
      VF_W.times do |c|
        sum, voltorbs = vf_totals(squares, (0...VF_W).map { |r| r * VF_W + c })
        out << PokeAccess::I18n.t(:mg_board_col, :n => c + 1, :sum => sum, :voltorbs => voltorbs)
      end
      out.join(". ")
    end

    # Voices the Mining cursor as it moves: grid position, the tile under it and, when it changes, the tool. Games
    # spell the width BOARD_WIDTH or BOARDWIDTH.
    def self.mining_cursor(cursor)
      pos = cursor.instance_variable_get(:@position).to_i
      mode = cursor.instance_variable_get(:@mode).to_i
      sig = [pos, mode]
      prev = cursor.instance_variable_get(:@pa_mine)
      return if sig == prev
      cursor.instance_variable_set(:@pa_mine, sig)
      w = (PokeAccess.const_at("MiningGameScene::BOARD_WIDTH") ||
           PokeAccess.const_at("MiningGameScene::BOARDWIDTH") || 13).to_i
      parts = [PokeAccess::I18n.t(:mg_rowcol, :row => pos / w + 1, :col => pos % w + 1)]
      tile = @mine_scene ? mining_tile(@mine_scene, pos) : nil
      parts << tile if tile
      parts << (mode == 0 ? PokeAccess::I18n.t(:mg_pick) : PokeAccess::I18n.t(:mg_hammer)) if prev.nil? || prev[1] != mode
      PokeAccess.speak(parts.join(", "), true, :menu)
    rescue StandardError
      nil
    end

    # The mine being played, for the cursor, which only knows its own square; set when the board is built.
    def self.mine_scene=(scene); @mine_scene = scene; end

    # What a wall square shows: its rock layers left or, once dug through, part of an item, iron or nothing.
    def self.mining_tile(scene, pos)
      layer = (PokeAccess.sprite(scene, "tile#{pos}").layer rescue nil)
      return nil if layer.nil?
      return PokeAccess::I18n.t(:mg_rock, :n => layer.to_i) if layer.to_i > 0
      return PokeAccess::I18n.t(:mg_tile_item) if (scene.pbIsItemThere?(pos) rescue false)
      return PokeAccess::I18n.t(:mg_tile_iron) if (scene.pbIsIronThere?(pos) rescue false)
      PokeAccess::I18n.t(:mg_tile_clear)
    end

    # How many dug-through squares show part of an item, over the whole board.
    def self.mining_exposed(scene)
      w = (PokeAccess.const_at("MiningGameScene::BOARD_WIDTH") ||
           PokeAccess.const_at("MiningGameScene::BOARDWIDTH") || 13).to_i
      h = (PokeAccess.const_at("MiningGameScene::BOARD_HEIGHT") ||
           PokeAccess.const_at("MiningGameScene::BOARDHEIGHT") || 10).to_i
      (0...(w * h)).count do |pos|
        (PokeAccess.sprite(scene, "tile#{pos}").layer rescue 1).to_i == 0 && (scene.pbIsItemThere?(pos) rescue false)
      end
    end

    # After a blow: the square under the cursor as it is now, and a notice when the blow uncovered part of an
    # item that is not yet whole (a whole one is announced as found).
    def self.mining_after_hit(scene, found)
      exposed = mining_exposed(scene)
      before = scene.instance_variable_get(:@pa_mine_exposed).to_i
      scene.instance_variable_set(:@pa_mine_exposed, exposed)
      parts = []
      parts << PokeAccess::I18n.t(:mg_item_peek) if exposed > before && !found
      tile = mining_tile(scene, (PokeAccess.sprite(scene, "cursor").position rescue 0).to_i)
      parts << tile if tile
      PokeAccess.speak(parts.join(", "), false, :menu) unless parts.empty?
    rescue StandardError
      nil
    end

    # Voices every item a Mining hit unearthed (one blow can uncover two); answers whether any was found.
    def self.mining_hit(scene)
      won = scene.instance_variable_get(:@itemswon) || []
      prev = scene.instance_variable_get(:@pa_mine_won).to_i
      return false unless won.length > prev
      scene.instance_variable_set(:@pa_mine_won, won.length)
      names = won[prev..-1].to_a.map { |it| PokeAccess::Data.item_name(it) }
      names = names.compact.reject { |n| n.to_s.empty? }
      return false if names.empty?
      PokeAccess.speak(names.map { |n| PokeAccess::I18n.t(:mg_found, :name => n) }.join(". "), false, :menu)
      true
    rescue StandardError
      false
    end

    # The wall caves in after 49 hits, its crack bar grows a block per 6 hits, and a hammer blow costs 2 hits.
    COLLAPSE_HITS = 49
    CRACK_BLOCK = 6
    HAMMER_HITS = 2

    # The blows of the tool in hand left before the wall caves in, queued, on each new crack block after the first.
    def self.mining_wall(scene)
      hits = (PokeAccess.sprite(scene, "crack").hits rescue nil)
      return if hits.nil?
      block = hits.to_i / CRACK_BLOCK
      moved = PokeAccess::Cursor.changed?(scene, :mine_wall, block)
      return unless moved && block > 0
      left = COLLAPSE_HITS - hits.to_i
      return if left <= 0
      hammer = (PokeAccess.sprite(scene, "cursor").instance_variable_get(:@mode) rescue 0).to_i == 1
      left = (left + HAMMER_HITS - 1) / HAMMER_HITS if hammer
      PokeAccess.speak(PokeAccess::I18n.t(:mg_wall_left, :n => left), false, :menu)
    rescue StandardError
      nil
    end

    # The eight Slot Machine reel symbols by index: 0 cherry, 1-4 Pokemon, 5/6 the red/blue 7, 7 replay.
    SLOT_SYMBOLS = [:mg_slot_cherry, :mg_slot_magnemite, :mg_slot_shellder, :mg_slot_pikachu,
                    :mg_slot_psyduck, :mg_slot_seven_red, :mg_slot_seven_blue, :mg_slot_replay]

    def self.slot_symbol(n)
      key = SLOT_SYMBOLS[n.to_i]
      key ? PokeAccess::I18n.t(key) : n.to_s
    end

    # Voices the wager (@wager, 0..3) when it changes; the 0 between spins is recorded, unsaid, so the same wager
    # next round is said again.
    def self.slot_wager(scene)
      w = scene.instance_variable_get(:@wager).to_i
      return unless PokeAccess::Cursor.changed?(scene, :slot_wager, w)
      return if w <= 0
      PokeAccess.speak(PokeAccess::I18n.t(:mg_slot_wager, :n => w), true, :menu)
    rescue StandardError
      nil
    end

    # Voices a reel's centre symbol (showing => [top, middle, bottom]) on the frame @spinning goes false; the reel
    # keeps slipping after stopSpinning, so that is when it lands.
    def self.slot_reel_update(reel)
      spinning = PokeAccess.ivar(reel, :@spinning) ? true : false
      was = PokeAccess.ivar(reel, :@access_spin) ? true : false
      reel.instance_variable_set(:@access_spin, spinning)
      return unless was && !spinning
      mid = (reel.showing[1] rescue nil)
      return if mid.nil?
      PokeAccess.speak(slot_symbol(mid), false, :menu)
    rescue StandardError
      nil
    end

    # The credit counter, where the winnings end up.
    def self.slot_credit(scene)
      (scene.instance_variable_get(:@sprites)["credit"].score rescue nil)
    end

    # Voices a spin's result: the lines played beyond the centre, the coins won (the credit's delta), the replay,
    # or the loss, then the credit.
    # param before the credit counter before pbPayout ran
    # param wager the coins played, sampled before pbPayout (which zeroes @wager)
    def self.slot_payout(scene, before, wager = nil)
      after = slot_credit(scene)
      won = (before && after) ? (after.to_i - before.to_i) : 0
      replay = scene.instance_variable_get(:@replay) ? true : false
      parts = slot_board_lines(scene, wager)
      parts.push(PokeAccess::I18n.t(:mg_slot_won, :n => won)) if won > 0
      parts.push(PokeAccess::I18n.t(:mg_slot_replay_win)) if replay
      parts.push(PokeAccess::I18n.t(:mg_slot_lost)) if won <= 0 && !replay
      parts.push(PokeAccess::I18n.t(:mg_slot_credit, :n => after.to_i)) if after
      PokeAccess.speak(parts.join(". "), false, :menu)
    rescue StandardError
      nil
    end

    # The lines played beyond the centre row (said reel by reel): 2 coins add top and bottom, 3 the diagonals.
    def self.slot_board_lines(scene, wager = nil)
      wager = (wager.nil? ? scene.instance_variable_get(:@wager) : wager).to_i
      return [] if wager < 2
      sprites = scene.instance_variable_get(:@sprites)
      cols = [1, 2, 3].map { |i| (sprites["reel#{i}"].showing rescue nil) }
      return [] if cols.any? { |c| !c.is_a?(Array) }
      row = lambda { |r| cols.map { |c| slot_symbol(c[r]) }.join(", ") }
      out = [PokeAccess::I18n.t(:mg_slot_row_top, :syms => row.call(0)),
             PokeAccess::I18n.t(:mg_slot_row_bottom, :syms => row.call(2))]
      if wager >= 3
        d1 = [cols[0][0], cols[1][1], cols[2][2]].map { |s| slot_symbol(s) }.join(", ")
        d2 = [cols[0][2], cols[1][1], cols[2][0]].map { |s| slot_symbol(s) }.join(", ")
        out.push(PokeAccess::I18n.t(:mg_slot_diag1, :syms => d1))
        out.push(PokeAccess::I18n.t(:mg_slot_diag2, :syms => d2))
      end
      out
    rescue StandardError
      []
    end

    # Duel (PokemonDuel): a DuelWindow's duelist and HP, when the HP changes.
    def self.duel_hp(win)
      hp = (win.hp rescue nil)
      return if hp.nil?
      return if win.instance_variable_get(:@pa_duel_hp) == hp
      win.instance_variable_set(:@pa_duel_hp, hp)
      name = (win.name rescue nil).to_s
      PokeAccess.speak(PokeAccess::I18n.t(:mg_duel_hp, :who => name, :hp => hp), false, :menu)
    rescue StandardError
      nil
    end

    # Tile Puzzle board width. @tiles maps position -> tile id (solved: id == position, angle 0); positions >= w*h
    # are the off-board reserve of games 1/2. Tiles are said by 1-based id.
    def self.tp_board_w(scene)
      (scene.instance_variable_get(:@boardwidth) || 4).to_i
    end

    # The cursor's cell: row/column or reserve, the tile on it, whether it is in place, its rotation when turned and,
    # with the puzzle help on, where it goes.
    def self.tp_cell(scene, pos)
      w = tp_board_w(scene)
      h = (scene.instance_variable_get(:@boardheight) || 4).to_i
      tiles = scene.instance_variable_get(:@tiles) || []
      angles = scene.instance_variable_get(:@angles) || []
      onboard = pos < w * h
      loc = onboard ? PokeAccess::I18n.t(:mg_rowcol, :row => pos / w + 1, :col => pos % w + 1) :
                      PokeAccess::I18n.t(:tp_reserve)
      tile = tiles[pos]
      parts = [loc]
      if tile.nil? || tile < 0
        parts << PokeAccess::I18n.t(:tp_empty)
      else
        parts << PokeAccess::I18n.t(:tp_tile, :n => tile + 1)
        placed = onboard && tile == pos && (angles[tile].to_i % 4) == 0
        parts << PokeAccess::I18n.t(:tp_placed) if placed
        ang = (angles[tile].to_i % 4)
        parts << PokeAccess::I18n.t(:tp_rotated, :deg => ang * 90) if ang != 0
        parts << tp_home(w, tile) if !placed && (PokeAccess::Config.puzzle_assist rescue false)
      end
      parts.join(", ")
    end

    # Where a piece goes: the square of its own number.
    def self.tp_home(w, tile)
      PokeAccess::I18n.t(:tp_home, :row => tile / w + 1, :col => tile % w + 1)
    end

    # The whole board for the info key: each row's pieces (those already right say so), the reserve when it
    # holds any, and how many are still out of place.
    def self.tp_board(scene)
      return PokeAccess::I18n.t(:tp_solved) if (scene.pbCheckWin rescue false)
      w = tp_board_w(scene)
      h = (scene.instance_variable_get(:@boardheight) || 4).to_i
      tiles = scene.instance_variable_get(:@tiles) || []
      angles = scene.instance_variable_get(:@angles) || []
      wrong = 0
      out = []
      h.times do |r|
        cells = (0...w).map do |c|
          i = r * w + c
          t = tiles[i]
          next PokeAccess::I18n.t(:tp_empty) if t.nil? || t < 0
          ok = t == i && (angles[t].to_i % 4) == 0
          wrong += 1 unless ok
          PokeAccess::I18n.t(:tp_tile, :n => t + 1) + (ok ? " " + PokeAccess::I18n.t(:tp_placed) : "")
        end
        out << PokeAccess::I18n.t(:tp_board_row, :n => r + 1, :cells => cells.join(", "))
      end
      spare = (w * h...tiles.length).map { |i| tiles[i] }.reject { |t| t.nil? || t < 0 }
      out << PokeAccess::I18n.t(:tp_reserve_holds, :cells => spare.map { |t| PokeAccess::I18n.t(:tp_tile, :n => t + 1) }.join(", ")) unless spare.empty?
      out << PokeAccess::I18n.t(:tp_wrong, :n => wrong + spare.length)
      out.join(". ")
    end

    # The legal moves the cursor sprite marks with its arrow overlays, as spoken direction words, or nil.
    # The game's own fill order is numpad (down, left, right, up).
    def self.tp_arrows(cur)
      arr = cur.instance_variable_get(:@arrows)
      return nil unless arr.is_a?(Array)
      names = [:dir_down, :dir_left, :dir_right, :dir_up]
      dirs = []
      arr.each_with_index { |on, i| dirs.push(PokeAccess::I18n.t(names[i])) if on && names[i] }
      dirs.empty? ? nil : dirs.join(", ")
    rescue StandardError
      nil
    end

    # Voices the Tile Puzzle: the win once solved, else the cursor cell, held tile and legal moves whenever that text
    # changes (picking up and rotating do not move the cursor).
    def self.tile_puzzle(scene)
      cur = (scene.instance_variable_get(:@sprites)["cursor"] rescue nil)
      return unless cur
      pos = cur.position.to_i
      solved = (scene.pbCheckWin rescue false)
      text = solved ? PokeAccess::I18n.t(:tp_solved) : tp_cell(scene, pos)
      unless solved
        held = scene.instance_variable_get(:@heldtile)
        text += ", " + PokeAccess::I18n.t(:tp_holding, :n => held.to_i + 1) if held && held.to_i >= 0
        dirs = tp_arrows(cur)
        text += ", " + PokeAccess::I18n.t(:tp_moves, :dirs => dirs) if dirs
      end
      sig = [pos, solved, text]
      return unless PokeAccess::Cursor.changed?(scene, :tp_cell, sig)
      PokeAccess.speak(text, true, :menu)
      PokeAccess::Info.set_info(:text, tp_board(scene))
    rescue StandardError
      nil
    end
  end
end

# Voltorb Flip; hook_container because getInput opens the quit confirmation inside itself, whose reader the
# reentrancy guard would otherwise drop as nested.
PokeAccess::Hooks.after_hook("VoltorbFlip", :getInput, :hook_container => true) { |scene, _result, _args| PokeAccess::Minigames.voltorb_flip(scene) }
# The boards parked for the info key are dropped as their screens start to close.
PokeAccess::Hooks.before_hook("VoltorbFlip", :pbEndScene, :optional => true) { |_s, _a| PokeAccess::Info.clear_text }
PokeAccess::Hooks.before_hook("TilePuzzleScene", :pbEndScene, :optional => true) { |_s, _a| PokeAccess::Info.clear_text }
PokeAccess::Hooks.after_hook("MiningGameCursor", :update) { |cursor, _result, _args| PokeAccess::Minigames.mining_cursor(cursor) }
PokeAccess::Hooks.before_hook("MiningGameScene", :pbStartScene) { |scene, _args| PokeAccess::Minigames.mine_scene = scene }
PokeAccess::Hooks.after_hook("MiningGameScene", :pbEndScene, :optional => true) do |_scene, _result, _args|
  PokeAccess::Minigames.mine_scene = nil
end
PokeAccess::Hooks.after_hook("MiningGameScene", :pbHit) do |scene, _result, _args|
  found = PokeAccess::Minigames.mining_hit(scene)
  PokeAccess::Minigames.mining_after_hit(scene, found)
  PokeAccess::Minigames.mining_wall(scene)
end

# Slot Machine (SlotMachineScene, its reels SlotMachineReel): wager as coins go in, each reel's symbol as it
# stops, and the win/loss once paid out. No-op where the classes are absent.
PokeAccess::Hooks.after_hook("SlotMachineScene", :update) { |scene, _r, _a| PokeAccess::Minigames.slot_wager(scene) }
PokeAccess::Hooks.after_hook("SlotMachineReel", :update) { |reel, _r, _a| PokeAccess::Minigames.slot_reel_update(reel) }
# pbPayout drains the payout into the credit and zeroes the wager: the credit is sampled on both sides, the wager
# before.
PokeAccess::Hooks.around_hook("SlotMachineScene", :pbPayout) do |scene, nxt, _a|
  before = PokeAccess::Minigames.slot_credit(scene)
  wager = scene.instance_variable_get(:@wager)
  begin; nxt.call; ensure; PokeAccess::Minigames.slot_payout(scene, before, wager); end
end

# Tile Puzzle (TilePuzzleScene), polled on the scene's per-frame update.
PokeAccess::Hooks.after_hook("TilePuzzleScene", :update) { |scene, _r, _a| PokeAccess::Minigames.tile_puzzle(scene) }

# Duel (DuelWindow): the refresh that runs on every change, duel_refresh (modern) or duelRefresh (pre-GameData).
PokeAccess::Hooks.after_hook("DuelWindow", :duel_refresh, :optional => true) { |win, _r, _a| PokeAccess::Minigames.duel_hp(win) }
PokeAccess::Hooks.after_hook("DuelWindow", :duelRefresh, :optional => true) { |win, _r, _a| PokeAccess::Minigames.duel_hp(win) }
