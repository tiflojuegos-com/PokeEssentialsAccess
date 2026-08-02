module PokeAccess
  # Accessibility for the standard Essentials minigames. Voltorb Flip is a 5x5 grid (@squares, index =
  # row*5+col, as [x,y,value,flipped]); voices the focused cell and, on a new row/column, that line's
  # coin sum and Voltorb count.
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
      sum = 0
      voltorbs = 0
      idxs.each do |i|
        v = (squares[i][2].to_i rescue 1)
        sum += v
        voltorbs += 1 if v == 0
      end
      PokeAccess::I18n.t(:mg_line, :label => label, :sum => sum, :voltorbs => voltorbs)
    end

    # Voices the Voltorb Flip cursor on change: position and cell always, the row/column hint on entering
    # a new one, and the mark/normal mode when it toggles.
    def self.voltorb_flip(scene)
      idx = scene.instance_variable_get(:@index)
      return unless idx.is_a?(Array)
      col = idx[0].to_i
      row = idx[1].to_i
      squares = scene.instance_variable_get(:@squares)
      marks = scene.instance_variable_get(:@marks)
      mode = (scene.instance_variable_get(:@cursor)[0][3] rescue 0).to_i
      cell = vf_cell(squares, marks, col, row)
      sig = [col, row, cell, mode]
      prev = scene.instance_variable_get(:@pa_vf)
      return if sig == prev
      scene.instance_variable_set(:@pa_vf, sig)
      parts = []
      parts << (mode == 0 ? PokeAccess::I18n.t(:mg_mode_normal) : PokeAccess::I18n.t(:mg_mode_mark)) if prev && prev[3] != mode
      parts << PokeAccess::I18n.t(:mg_rowcol, :row => row + 1, :col => col + 1)
      parts << cell unless cell.empty?
      parts << vf_line(squares, (0...VF_W).map { |c| row * VF_W + c }, PokeAccess::I18n.t(:mg_row)) if prev.nil? || prev[1] != row
      parts << vf_line(squares, (0...VF_W).map { |r| r * VF_W + col }, PokeAccess::I18n.t(:mg_col)) if prev.nil? || prev[0] != col
      PokeAccess.speak(parts.join(", "), true)
    rescue StandardError
      nil
    end

    # Voices the Mining cursor as it moves: grid position and, when it changes, the tool.
    def self.mining_cursor(cursor)
      pos = cursor.instance_variable_get(:@position).to_i
      mode = cursor.instance_variable_get(:@mode).to_i
      sig = [pos, mode]
      prev = cursor.instance_variable_get(:@pa_mine)
      return if sig == prev
      cursor.instance_variable_set(:@pa_mine, sig)
      w = (MiningGameScene::BOARD_WIDTH rescue 13)
      parts = [PokeAccess::I18n.t(:mg_rowcol, :row => pos / w + 1, :col => pos % w + 1)]
      parts << (mode == 0 ? PokeAccess::I18n.t(:mg_pick) : PokeAccess::I18n.t(:mg_hammer)) if prev.nil? || prev[1] != mode
      PokeAccess.speak(parts.join(", "), true)
    rescue StandardError
      nil
    end

    # Voices the result of a Mining hit: any newly unearthed item, else nothing (digging stays quiet).
    def self.mining_hit(scene)
      won = scene.instance_variable_get(:@itemswon) || []
      prev = scene.instance_variable_get(:@pa_mine_won).to_i
      return unless won.length > prev
      scene.instance_variable_set(:@pa_mine_won, won.length)
      name = PokeAccess::Data.item_name(won.last)
      PokeAccess.speak(PokeAccess::I18n.t(:mg_found, :name => name), false) if name && !name.to_s.empty?
    rescue StandardError
      nil
    end

    # The eight Slot Machine reel symbols, spoken by name (they are drawn as pictures, so the sighted-only
    # icon is turned into an i18n key: 0 cherry, 1-4 Pokemon, 5/6 the red/blue 7, 7 the replay symbol).
    SLOT_SYMBOLS = [:mg_slot_cherry, :mg_slot_magnemite, :mg_slot_shellder, :mg_slot_pikachu,
                    :mg_slot_psyduck, :mg_slot_seven_red, :mg_slot_seven_blue, :mg_slot_replay]

    def self.slot_symbol(n)
      key = SLOT_SYMBOLS[n.to_i]
      key ? PokeAccess::I18n.t(key) : n.to_s
    end

    # Voices the wager as coins are inserted (@wager, 0..3, one row of paylines each). Deduped so the number
    # is spoken once per change, not every frame of the awaiting-coins loop.
    def self.slot_wager(scene)
      w = scene.instance_variable_get(:@wager).to_i
      return if w <= 0
      return unless PokeAccess::Cursor.changed?(scene, :slot_wager, w)
      PokeAccess.speak(PokeAccess::I18n.t(:mg_slot_wager, :n => w), true)
    rescue StandardError
      nil
    end

    # Voices a reel's centre-row symbol the moment it is told to stop, so the player learns each reel's result
    # as it lands (showing => [top, middle, bottom]; the centre row is the one a single coin always plays).
    def self.slot_reel_stop(reel)
      mid = (reel.showing[1] rescue nil)
      return if mid.nil?
      PokeAccess.speak(slot_symbol(mid), false)
    rescue StandardError
      nil
    end

    # Voices the payout once the reels have stopped: the coins won (credited to the payout counter) or that the
    # spin lost. Read after pbPayout has set @sprites["payout"].score. @replay means all three 7s replay symbol.
    def self.slot_payout(scene)
      replay = scene.instance_variable_get(:@replay)
      won = (scene.instance_variable_get(:@sprites)["payout"].score rescue 0).to_i
      if replay
        PokeAccess.speak(PokeAccess::I18n.t(:mg_slot_replay_win), false)
      elsif won > 0
        PokeAccess.speak(PokeAccess::I18n.t(:mg_slot_won, :n => won), false)
      else
        PokeAccess.speak(PokeAccess::I18n.t(:mg_slot_lost), false)
      end
    rescue StandardError
      nil
    end

    # Duel (PokemonDuel): a command duel whose narration already goes through pbMessage, so only the two
    # HUD windows are silent -- each DuelWindow redraws "name / HP: n" into its own bitmap on every change.
    # Voice the duelist and its new HP whenever the value actually changes.
    def self.duel_hp(win)
      hp = (win.hp rescue nil)
      return if hp.nil?
      return if win.instance_variable_get(:@pa_duel_hp) == hp
      win.instance_variable_set(:@pa_duel_hp, hp)
      name = (win.name rescue nil).to_s
      PokeAccess.speak(PokeAccess::I18n.t(:mg_duel_hp, :who => name, :hp => hp), false)
    rescue StandardError
      nil
    end

    # Tile Puzzle: an NxN board of picture tiles the player rearranges. @tiles maps board position -> tile id
    # (the solved state is tile id == position, angle 0); the cursor position is @sprites["cursor"].position.
    # The tile is identified by its 1-based id so a blind player can track pieces; games 1/2 have a second
    # off-board staging area (positions >= w*h), spoken as the reserve.
    def self.tp_board_w(scene)
      (scene.instance_variable_get(:@boardwidth) || 4).to_i
    end

    # The spoken description of the cursor's current cell: its row/column (or reserve slot), which tile sits
    # there (by id), whether that tile is already in its solved place, and its rotation when turned.
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
        parts << PokeAccess::I18n.t(:tp_placed) if onboard && tile == pos && (angles[tile].to_i % 4) == 0
        ang = (angles[tile].to_i % 4)
        parts << PokeAccess::I18n.t(:tp_rotated, :deg => ang * 90) if ang != 0
      end
      parts.join(", ")
    end

    # Voices the Tile Puzzle each frame: the win the moment the board is solved, else the cursor cell whenever
    # it moves. Deduped by [pos, solved] so a held cursor stays quiet.
    def self.tile_puzzle(scene)
      cur = (scene.instance_variable_get(:@sprites)["cursor"] rescue nil)
      return unless cur
      pos = cur.position.to_i
      solved = (scene.pbCheckWin rescue false)
      sig = [pos, solved]
      prev = scene.instance_variable_get(:@pa_tp)
      return if sig == prev
      scene.instance_variable_set(:@pa_tp, sig)
      if solved
        PokeAccess.speak(PokeAccess::I18n.t(:tp_solved), true)
      else
        PokeAccess.speak(tp_cell(scene, pos), true)
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("VoltorbFlip", :getInput) { |scene, _result, _args| PokeAccess::Minigames.voltorb_flip(scene) }
PokeAccess::Hooks.after_hook("MiningGameCursor", :update) { |cursor, _result, _args| PokeAccess::Minigames.mining_cursor(cursor) }
PokeAccess::Hooks.after_hook("MiningGameScene", :pbHit) { |scene, _result, _args| PokeAccess::Minigames.mining_hit(scene) }

# Slot Machine (SlotMachineScene, its reels SlotMachineReel): wager as coins go in, each reel's symbol as it
# stops, and the win/loss once paid out. No-op where the classes are absent.
PokeAccess::Hooks.after_hook("SlotMachineScene", :update) { |scene, _r, _a| PokeAccess::Minigames.slot_wager(scene) }
PokeAccess::Hooks.after_hook("SlotMachineReel", :stopSpinning) { |reel, _r, _a| PokeAccess::Minigames.slot_reel_stop(reel) }
PokeAccess::Hooks.after_hook("SlotMachineScene", :pbPayout) { |scene, _r, _a| PokeAccess::Minigames.slot_payout(scene) }

# Tile Puzzle (TilePuzzleScene): the cursor cell as it moves and the win when solved, polled on the scene's
# per-frame update. The cursor and board live in the scene's ivars, so no around-hook is needed.
PokeAccess::Hooks.after_hook("TilePuzzleScene", :update) { |scene, _r, _a| PokeAccess::Minigames.tile_puzzle(scene) }

# Duel (DuelWindow): only the HP readout is silent; the refresh runs on every change, including the
# initial draw, so hooking it covers both windows without a poller. The method is duel_refresh in the
# modern minigame and duelRefresh in the pre-GameData one (same window shape either way); each game has
# exactly one of the two, hence both optional.
PokeAccess::Hooks.after_hook("DuelWindow", :duel_refresh, :optional => true) { |win, _r, _a| PokeAccess::Minigames.duel_hp(win) }
PokeAccess::Hooks.after_hook("DuelWindow", :duelRefresh, :optional => true) { |win, _r, _a| PokeAccess::Minigames.duel_hp(win) }
