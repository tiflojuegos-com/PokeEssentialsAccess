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

    # Voices the Mining cursor as it moves: grid position and, when it changes, the tool. The board width is
    # asked for under both spellings that ship -- some games declare BOARD_WIDTH, others BOARDWIDTH -- so
    # asking for one alone fell silently through to the hand-written 13 on the rest. It happens to be 13
    # everywhere today, which is exactly why nobody noticed: the first game to widen its board would have
    # read a wrong grid.
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
      parts << (mode == 0 ? PokeAccess::I18n.t(:mg_pick) : PokeAccess::I18n.t(:mg_hammer)) if prev.nil? || prev[1] != mode
      PokeAccess.speak(parts.join(", "), true)
    rescue StandardError
      nil
    end

    # Voices the result of a Mining hit: every newly unearthed item, else nothing (digging stays quiet).
    #
    # TODOS los nuevos, no solo el ultimo. Un martillazo puede descubrir dos piezas de golpe -- las dos se
    # revelan en el mismo frame -- y nombrar won.last dejaba la otra sin decir: en una pantalla que existe
    # para saber que has sacado, eso es un objeto que el jugador no sabe que tiene.
    def self.mining_hit(scene)
      won = scene.instance_variable_get(:@itemswon) || []
      prev = scene.instance_variable_get(:@pa_mine_won).to_i
      return unless won.length > prev
      scene.instance_variable_set(:@pa_mine_won, won.length)
      names = won[prev..-1].to_a.map { |it| PokeAccess::Data.item_name(it) }
      names = names.compact.reject { |n| n.to_s.empty? }
      return if names.empty?
      PokeAccess.speak(names.map { |n| PokeAccess::I18n.t(:mg_found, :name => n) }.join(". "), false)
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
    #
    # El cero se traga la clave en vez de saltarse el dedup. Entre tirada y tirada @wager vuelve a 0, y si
    # ese paso no se registra la ranura conserva la apuesta anterior: repetir la misma apuesta en la ronda
    # siguiente -- que es lo que hace cualquiera -- se lee como "sin cambio" y entra muda.
    def self.slot_wager(scene)
      w = scene.instance_variable_get(:@wager).to_i
      return unless PokeAccess::Cursor.changed?(scene, :slot_wager, w)
      return if w <= 0
      PokeAccess.speak(PokeAccess::I18n.t(:mg_slot_wager, :n => w), true)
    rescue StandardError
      nil
    end

    # Voices a reel's centre-row symbol on the frame it actually lands (showing => [top, middle, bottom]; the
    # centre row is the one a single coin always plays).
    #
    # Polled from the reel's own update rather than hung off stopSpinning, which was naming the wrong symbol
    # on every spin: stopSpinning only raises @stopping and picks a random slip, and the reel keeps advancing
    # inside update until @toppos is 0 with no slip left -- up to four symbols further on, and the modern copy
    # widens the slip by difficulty. The landing is the frame @spinning goes false, which is exactly what the
    # remembered flag detects. Both eras share @spinning, showing and update, so one reader serves them.
    def self.slot_reel_update(reel)
      spinning = PokeAccess.ivar(reel, :@spinning) ? true : false
      was = PokeAccess.ivar(reel, :@access_spin) ? true : false
      reel.instance_variable_set(:@access_spin, spinning)
      return unless was && !spinning
      mid = (reel.showing[1] rescue nil)
      return if mid.nil?
      PokeAccess.speak(slot_symbol(mid), false)
    rescue StandardError
      nil
    end

    # The credit counter, which is where the winnings actually end up.
    def self.slot_credit(scene)
      (scene.instance_variable_get(:@sprites)["credit"].score rescue nil)
    end

    # Voices the result of a spin: the coins won, the free replay, or the loss. param before the credit
    # counter as it stood before pbPayout ran.
    #
    # The prize is the CREDIT delta, not the payout counter. Reading @sprites["payout"].score after pbPayout
    # returns always answered zero -- the method sets it to the prize and then its own counting loop drains it
    # one coin at a time into the credit, so every win, in all thirteen games, was announced as a loss. Only
    # pbPayout adds to the credit (the wager is deducted elsewhere), so the difference IS the prize, whether
    # the player let the count run or skipped it.
    # Premio y repeticion NO son excluyentes: una combinacion puede pagar monedas y regalar la tirada a la
    # vez, y contarlos con un elsif hacia perder el premio detras del aviso de repeticion. "Has perdido" solo
    # cuando no hay ninguna de las dos cosas.
    def self.slot_payout(scene, before)
      after = slot_credit(scene)
      won = (before && after) ? (after.to_i - before.to_i) : 0
      replay = scene.instance_variable_get(:@replay) ? true : false
      parts = []
      parts.push(PokeAccess::I18n.t(:mg_slot_won, :n => won)) if won > 0
      parts.push(PokeAccess::I18n.t(:mg_slot_replay_win)) if replay
      parts.push(PokeAccess::I18n.t(:mg_slot_lost)) if parts.empty?
      PokeAccess.speak(parts.join(". "), false)
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
    # it changes.
    #
    # La firma lleva el TEXTO de la celda, no solo la posicion. Coger una pieza y girarla son las dos acciones
    # del puzle y ninguna mueve el cursor: sobre [pos, solved] la celda queda igual y las dos entran mudas,
    # asi que el jugador gira a ciegas sin saber en que angulo esta.
    def self.tile_puzzle(scene)
      cur = (scene.instance_variable_get(:@sprites)["cursor"] rescue nil)
      return unless cur
      pos = cur.position.to_i
      solved = (scene.pbCheckWin rescue false)
      text = solved ? PokeAccess::I18n.t(:tp_solved) : tp_cell(scene, pos)
      sig = [pos, solved, text]
      prev = scene.instance_variable_get(:@pa_tp)
      return if sig == prev
      scene.instance_variable_set(:@pa_tp, sig)
      PokeAccess.speak(text, true)
    rescue StandardError
      nil
    end
  end
end

# hook_container: getInput abre la confirmacion de salir DENTRO de si mismo, asi que con la guarda de
# reentrancia puesta el lector de mensajes cae como anidado y el si/no se queda sin leer -- se oye la
# pregunta y despues nada, sin forma de saber que opcion esta marcada.
PokeAccess::Hooks.after_hook("VoltorbFlip", :getInput, :hook_container => true) { |scene, _result, _args| PokeAccess::Minigames.voltorb_flip(scene) }
PokeAccess::Hooks.after_hook("MiningGameCursor", :update) { |cursor, _result, _args| PokeAccess::Minigames.mining_cursor(cursor) }
PokeAccess::Hooks.after_hook("MiningGameScene", :pbHit) { |scene, _result, _args| PokeAccess::Minigames.mining_hit(scene) }

# Slot Machine (SlotMachineScene, its reels SlotMachineReel): wager as coins go in, each reel's symbol as it
# stops, and the win/loss once paid out. No-op where the classes are absent.
PokeAccess::Hooks.after_hook("SlotMachineScene", :update) { |scene, _r, _a| PokeAccess::Minigames.slot_wager(scene) }
PokeAccess::Hooks.after_hook("SlotMachineReel", :update) { |reel, _r, _a| PokeAccess::Minigames.slot_reel_update(reel) }
# pbPayout is the coin-counting animation: the prize exists only while it runs, and by the time it returns
# the counter it was read from is back to zero. Wrapped instead, so the credit is sampled on both sides.
PokeAccess::Hooks.around_hook("SlotMachineScene", :pbPayout) do |scene, nxt, _a|
  before = PokeAccess::Minigames.slot_credit(scene)
  begin; nxt.call; ensure; PokeAccess::Minigames.slot_payout(scene, before); end
end

# Tile Puzzle (TilePuzzleScene): the cursor cell as it moves and the win when solved, polled on the scene's
# per-frame update. The cursor and board live in the scene's ivars, so no around-hook is needed.
PokeAccess::Hooks.after_hook("TilePuzzleScene", :update) { |scene, _r, _a| PokeAccess::Minigames.tile_puzzle(scene) }

# Duel (DuelWindow): only the HP readout is silent; the refresh runs on every change, including the
# initial draw, so hooking it covers both windows without a poller. The method is duel_refresh in the
# modern minigame and duelRefresh in the pre-GameData one (same window shape either way); each game has
# exactly one of the two, hence both optional.
PokeAccess::Hooks.after_hook("DuelWindow", :duel_refresh, :optional => true) { |win, _r, _a| PokeAccess::Minigames.duel_hp(win) }
PokeAccess::Hooks.after_hook("DuelWindow", :duelRefresh, :optional => true) { |win, _r, _a| PokeAccess::Minigames.duel_hp(win) }
