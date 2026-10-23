module PokeAccess
  # The standard Essentials minigames: Voltorb Flip, Mining, Slot Machine, Duel and Tile Puzzle. Voltorb Flip's
  # @squares is a 5x5 grid, index row*5+col, each [x, y, value, flipped].
  module Minigames
    VF_W = 5

    # Parks text as the info key's line for a minigame's scene: set as the screen's text and kept for the map's info
    # owner, since the frames a minigame runs over the map (pbWait) reset the key to the map.
    def self.publish(scene, text)
      @board = [scene, text]
      PokeAccess::Info.set_info(:text, text)
    end

    # Drops the parked line as the minigame's screen closes.
    def self.unpublish
      @board = nil
      PokeAccess::Info.clear_text
    end

    # The parked line while its scene is up (its viewport not disposed), else nil: the info key's answer on the map.
    def self.board
      return nil unless @board
      vp = @board[0].instance_variable_get(:@viewport)
      return nil if vp && (vp.disposed? rescue false)
      @board[1]
    end

    # The spoken state of one Voltorb Flip cell: its value once flipped or with the whole board face up (reveal),
    # else marked or hidden.
    def self.vf_cell(squares, marks, col, row, reveal = false)
      cell = (squares[row * VF_W + col] rescue nil)
      return "" unless cell.is_a?(Array)
      return (cell[2].to_i == 0 ? PokeAccess::I18n.t(:mg_voltorb) : cell[2].to_s) if cell[3] || reveal
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

    # The coins the player holds (the Coin Case), on whichever holder the era keeps them: $player, $Trainer or
    # $PokemonGlobal; nil when none does.
    def self.held_coins
      [$player, $Trainer, $PokemonGlobal].each do |h|
        return h.coins.to_i if h && h.respond_to?(:coins)
      end
      nil
    end

    # The keys the Voltorb Flip board paints: the memo's (Ctrl before GameData, the action button after) and, before
    # GameData, quitting's.
    def self.vf_keys
      if PokeAccess::Engine.gen6?
        [PokeAccess::I18n.t(:mg_vf_memo_key, :key => PokeAccess::I18n.t(:key_control)),
         PokeAccess::I18n.t(:piano_exit, :key => PokeAccess::KeyHints.key(:b, "X"))].join(". ")
      else
        PokeAccess::I18n.t(:mg_vf_memo_key, :key => PokeAccess::KeyHints.key(:a, "Z"))
      end
    end

    # The board's side panel as said: the level, the coins held and, with earned, the coins won on this board.
    def self.vf_status(scene, earned = true)
      coins = held_coins
      out = [PokeAccess::I18n.t(:mg_level, :n => scene.instance_variable_get(:@level).to_i)]
      out << PokeAccess::I18n.t(:mg_coins, :n => coins) if coins
      out << PokeAccess::I18n.t(:mg_vf_earned, :n => scene.instance_variable_get(:@points).to_i) if earned
      out
    end

    # Voices the Voltorb Flip cursor on change (square, card, line hints, mode, coins won); a new board adds its level,
    # the coins held and, the first one, its keys. Silent once the game quits (@quit), as no board is played then.
    def self.voltorb_flip(scene)
      return if scene.instance_variable_get(:@quit)
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
      seen = scene.instance_variable_get(:@pa_vf)
      return if sig == seen
      scene.instance_variable_set(:@pa_vf, sig)
      prev = (seen && seen[5] == board) ? seen : nil
      parts = []
      parts.concat(vf_status(scene, false)) if prev.nil?
      parts << (mode == 0 ? PokeAccess::I18n.t(:mg_mode_normal) : PokeAccess::I18n.t(:mg_mode_mark)) if prev && prev[3] != mode
      parts << PokeAccess::I18n.t(:mg_vf_earned, :n => pts) if prev && prev[4] != pts
      parts << PokeAccess::I18n.t(:mg_rowcol, :row => row + 1, :col => col + 1)
      parts << cell unless cell.empty?
      parts << vf_line(squares, (0...VF_W).map { |c| row * VF_W + c }, PokeAccess::I18n.t(:mg_row)) if prev.nil? || prev[1] != row
      parts << vf_line(squares, (0...VF_W).map { |r| r * VF_W + col }, PokeAccess::I18n.t(:mg_col)) if prev.nil? || prev[0] != col
      text = parts.join(", ")
      text = PokeAccess::Verbosity.with_hint(text, vf_keys) if seen.nil?
      PokeAccess.speak(text, true, :menu)
      publish(scene, vf_info(scene))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The whole board for the info key: each row's five cards with its sum and Voltorbs, then each column's; with
    # reveal, every card face up and no columns, which add nothing then.
    def self.vf_board(squares, marks, reveal = false)
      out = []
      VF_W.times do |r|
        cells = (0...VF_W).map { |c| vf_cell(squares, marks, c, r, reveal) }
        sum, voltorbs = vf_totals(squares, (0...VF_W).map { |c| r * VF_W + c })
        out << PokeAccess::I18n.t(:mg_board_row, :n => r + 1, :cells => cells.join(", "), :sum => sum, :voltorbs => voltorbs)
      end
      unless reveal
        VF_W.times do |c|
          sum, voltorbs = vf_totals(squares, (0...VF_W).map { |r| r * VF_W + c })
          out << PokeAccess::I18n.t(:mg_board_col, :n => c + 1, :sum => sum, :voltorbs => voltorbs)
        end
      end
      out.join(". ")
    end

    # The info key's Voltorb Flip line: the side panel (vf_status), then the board, face up with reveal.
    def self.vf_info(scene, reveal = false)
      board = vf_board(scene.instance_variable_get(:@squares), scene.instance_variable_get(:@marks), reveal)
      "#{vf_status(scene).join(', ')}. #{board}"
    end

    # Voices, queued, the board pbShowAndDispose turns face up before it waits for a key (after a Voltorb, a cleared
    # board or quitting): every card row by row, and the key that goes on; the info key gives it too.
    def self.vf_reveal(scene)
      squares = scene.instance_variable_get(:@squares)
      return unless squares.is_a?(Array) && squares.length >= VF_W * VF_W
      hint = PokeAccess::I18n.t(:title_press, :key => PokeAccess::KeyHints.key(:c, "C"))
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(vf_board(squares, nil, true), hint), false, :menu)
      publish(scene, vf_info(scene, true))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The wall's width and height as the game spells them (BOARD_WIDTH or BOARDWIDTH), else 13 by 10.
    def self.mine_size
      w = (PokeAccess.const_at("MiningGameScene::BOARD_WIDTH") ||
           PokeAccess.const_at("MiningGameScene::BOARDWIDTH") || 13).to_i
      h = (PokeAccess.const_at("MiningGameScene::BOARD_HEIGHT") ||
           PokeAccess.const_at("MiningGameScene::BOARDHEIGHT") || 10).to_i
      [w, h]
    end

    # Voices the Mining cursor as it moves: grid position, the tile under it and, when it changes, the tool with the
    # blows it has left; publishes the wall for the info key.
    def self.mining_cursor(cursor)
      pos = cursor.instance_variable_get(:@position).to_i
      mode = cursor.instance_variable_get(:@mode).to_i
      sig = [pos, mode]
      prev = cursor.instance_variable_get(:@pa_mine)
      return if sig == prev
      cursor.instance_variable_set(:@pa_mine, sig)
      w = mine_size[0]
      scene = @mine_scene
      parts = [PokeAccess::I18n.t(:mg_rowcol, :row => pos / w + 1, :col => pos % w + 1)]
      tile = scene ? mining_tile(scene, pos) : nil
      parts << tile if tile
      if prev.nil? || prev[1] != mode
        parts << (mode == 0 ? PokeAccess::I18n.t(:mg_pick) : PokeAccess::I18n.t(:mg_hammer))
        left = (prev && scene) ? mining_left(scene, mode == 1) : nil
        parts << PokeAccess::I18n.t(:mg_wall_left, :n => left) if left
      end
      PokeAccess.speak(parts.join(", "), true, :menu)
      publish(scene, mining_board(scene)) if scene
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The mine being played, for the cursor, which only knows its own square; set when the board is built.
    def self.mine_scene=(scene); @mine_scene = scene; end

    # What a wall square shows: its rock layers left or, once dug through, part of an item (one already dug out said
    # apart), iron or nothing.
    def self.mining_tile(scene, pos)
      layer = (PokeAccess.sprite(scene, "tile#{pos}").layer rescue nil)
      return nil if layer.nil?
      return PokeAccess::I18n.t(:mg_rock, :n => layer.to_i) if layer.to_i > 0
      if (scene.pbIsItemThere?(pos) rescue false)
        return PokeAccess::I18n.t(mining_won_at?(scene, pos) ? :mg_tile_item_won : :mg_tile_item)
      end
      return PokeAccess::I18n.t(:mg_tile_iron) if (scene.pbIsIronThere?(pos) rescue false)
      PokeAccess::I18n.t(:mg_tile_clear)
    end

    # Whether the item part on square pos belongs to an item already dug out (its @items row flagged [3] as it
    # flashes), by the game's ITEMS table: [item, odds, x, y, width, height, pattern].
    def self.mining_won_at?(scene, pos)
      table = PokeAccess.const_at("MiningGameScene::ITEMS")
      return false unless table
      w = mine_size[0]
      x = pos % w
      y = pos / w
      (scene.instance_variable_get(:@items) || []).any? do |entry|
        row = table[entry[0]]
        dx = x - entry[1].to_i
        dy = y - entry[2].to_i
        entry[3] && dx >= 0 && dy >= 0 && dx < row[4] && dy < row[5] && row[6][dx + dy * row[4]].to_i > 0
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The dug-through squares of the wall: [those showing part of an item not yet dug out, those showing iron, how
    # many in all].
    def self.mining_sights(scene)
      w, h = mine_size
      items = []
      iron = []
      dug = 0
      (0...(w * h)).each do |pos|
        next unless (PokeAccess.sprite(scene, "tile#{pos}").layer rescue 1).to_i == 0
        dug += 1
        if (scene.pbIsItemThere?(pos) rescue false)
          items.push(pos) unless mining_won_at?(scene, pos)
        elsif (scene.pbIsIronThere?(pos) rescue false)
          iron.push(pos)
        end
      end
      [items, iron, dug]
    end

    # Wall squares as said, row and column each.
    def self.mine_squares(list)
      w = mine_size[0]
      list.map { |pos| PokeAccess::I18n.t(:mg_rowcol, :row => pos / w + 1, :col => pos % w + 1) }.join(", ")
    end

    # The info key's line for the wall: the cracks of COLLAPSE_HITS, where part of an item not yet dug out shows,
    # where iron shows, and how many squares are dug through.
    def self.mining_board(scene)
      items, iron, dug = mining_sights(scene)
      hits = (PokeAccess.sprite(scene, "crack").hits rescue 0).to_i
      parts = [PokeAccess::I18n.t(:mg_mine_cracks, :n => hits, :max => COLLAPSE_HITS)]
      parts << PokeAccess::I18n.t(:mg_item_at, :where => mine_squares(items)) unless items.empty?
      parts << PokeAccess::I18n.t(:mg_iron_at, :where => mine_squares(iron)) unless iron.empty?
      parts << PokeAccess::I18n.t(:mg_mine_dug, :n => dug)
      parts.join(". ")
    end

    # After a blow: where else part of an item not dug out or iron came into sight since the last, then the square
    # under the cursor as it is now; republishes the wall for the info key.
    def self.mining_after_hit(scene)
      items, iron = mining_sights(scene)
      seen = scene.instance_variable_get(:@pa_mine_seen) || [[], []]
      scene.instance_variable_set(:@pa_mine_seen, [items, iron])
      pos = (PokeAccess.sprite(scene, "cursor").position rescue 0).to_i
      new_items = items.reject { |sq| sq == pos || seen[0].include?(sq) }
      new_iron = iron.reject { |sq| sq == pos || seen[1].include?(sq) }
      parts = []
      parts << PokeAccess::I18n.t(:mg_item_at, :where => mine_squares(new_items)) unless new_items.empty?
      parts << PokeAccess::I18n.t(:mg_iron_at, :where => mine_squares(new_iron)) unless new_iron.empty?
      tile = mining_tile(scene, pos)
      parts << tile if tile
      PokeAccess.speak(parts.join(", "), false, :menu) unless parts.empty?
      publish(scene, mining_board(scene))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Voices every item a Mining hit unearthed (one blow can uncover two).
    def self.mining_hit(scene)
      won = scene.instance_variable_get(:@itemswon) || []
      prev = scene.instance_variable_get(:@pa_mine_won).to_i
      return unless won.length > prev
      scene.instance_variable_set(:@pa_mine_won, won.length)
      names = won[prev..-1].to_a.map { |it| PokeAccess::Data.item_name(it) }
      names = names.compact.reject { |n| n.to_s.empty? }
      return if names.empty?
      PokeAccess.speak(names.map { |n| PokeAccess::I18n.t(:mg_found, :name => n) }.join(". "), false, :menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The wall caves in after 49 hits, its crack bar grows a block per 6 hits, and a hammer blow costs 2 hits.
    COLLAPSE_HITS = 49
    CRACK_BLOCK = 6
    HAMMER_HITS = 2

    # The blows of the pick, or of the hammer, left before the wall caves in; nil once it has, or with no crack bar.
    def self.mining_left(scene, hammer)
      hits = (PokeAccess.sprite(scene, "crack").hits rescue nil)
      return nil if hits.nil?
      left = COLLAPSE_HITS - hits.to_i
      return nil if left <= 0
      hammer ? (left + HAMMER_HITS - 1) / HAMMER_HITS : left
    end

    # The blows of the tool in hand left before the wall caves in, queued, on each new crack block after the first.
    def self.mining_wall(scene)
      hits = (PokeAccess.sprite(scene, "crack").hits rescue nil)
      return if hits.nil?
      block = hits.to_i / CRACK_BLOCK
      moved = PokeAccess::Cursor.changed?(scene, :mine_wall, block)
      return unless moved && block > 0
      hammer = (PokeAccess.sprite(scene, "cursor").instance_variable_get(:@mode) rescue 0).to_i == 1
      left = mining_left(scene, hammer)
      PokeAccess.speak(PokeAccess::I18n.t(:mg_wall_left, :n => left), false, :menu) if left
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The eight Slot Machine reel symbols by index: 0 cherry, 1-4 Pokemon, 5/6 the red/blue 7, 7 replay.
    SLOT_SYMBOLS = [:mg_slot_cherry, :mg_slot_magnemite, :mg_slot_shellder, :mg_slot_pikachu,
                    :mg_slot_psyduck, :mg_slot_seven_red, :mg_slot_seven_blue, :mg_slot_replay]

    # The five lines of the window in pbPayout's order, each its said key and the row it reads on reels 1-3: the
    # centre, then the top and bottom (two coins), then the diagonals (three).
    SLOT_LINES = [[:mg_slot_row_mid, [1, 1, 1]], [:mg_slot_row_top, [0, 0, 0]], [:mg_slot_row_bottom, [2, 2, 2]],
                  [:mg_slot_diag1, [0, 1, 2]], [:mg_slot_diag2, [2, 1, 0]]]

    def self.slot_symbol(n)
      key = SLOT_SYMBOLS[n.to_i]
      key ? PokeAccess::I18n.t(key) : n.to_s
    end

    # Voices, queued, the slot machine as its loop starts: the credit, then its three keys as a hint; publishes the
    # info key's line.
    def self.slot_open(scene)
      publish(scene, slot_info(scene))
      credit = slot_credit(scene)
      parts = []
      parts << PokeAccess::I18n.t(:mg_slot_credit, :n => credit.to_i) if credit
      if PokeAccess::Verbosity.hints?
        parts << PokeAccess::I18n.t(:mg_slot_keys, :wager => PokeAccess::KeyHints.key(:down, PokeAccess::I18n.t(:key_arrow_down)),
                                    :spin => PokeAccess::KeyHints.key(:c, "C"), :quit => PokeAccess::KeyHints.key(:b, "X"))
      end
      PokeAccess.speak(parts.join(". "), false, :menu) unless parts.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Voices the wager (@wager, 0..3) as a coin goes in, with the credit left and, while the reels wait for C, the
    # key that spins them; the 0 between spins and the free spin's 3 (@replay, no coin in) are recorded, unsaid.
    def self.slot_wager(scene)
      w = scene.instance_variable_get(:@wager).to_i
      return unless PokeAccess::Cursor.changed?(scene, :slot_wager, w)
      publish(scene, slot_info(scene))
      return if w <= 0 || scene.instance_variable_get(:@replay)
      credit = slot_credit(scene)
      text = PokeAccess::I18n.t(:mg_slot_wager, :n => w)
      text = "#{text}, #{PokeAccess::I18n.t(:mg_slot_credit, :n => credit.to_i)}" if credit
      if w < 3 && credit.to_i > 0
        text = PokeAccess::Verbosity.with_hint(text, PokeAccess::I18n.t(:mg_slot_spin_hint, :key => PokeAccess::KeyHints.key(:c, "C")))
      end
      PokeAccess.speak(text, true, :menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Voices, queued, the reels starting to spin (gameRunning turning true), with the key that stops them.
    def self.slot_spin(scene)
      running = (scene.gameRunning rescue false) ? true : false
      return unless PokeAccess::Cursor.changed?(scene, :slot_spin, running) && running
      hint = PokeAccess::I18n.t(:mg_slot_stop_hint, :key => PokeAccess::KeyHints.key(:c, "C"))
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:mg_slot_spinning), hint), false, :menu)
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The credit counter, where the winnings end up.
    def self.slot_credit(scene)
      (scene.instance_variable_get(:@sprites)["credit"].score rescue nil)
    end

    # The info key's slot machine line: the credit, the coins in, and the prize table painted under the reels.
    def self.slot_info(scene)
      parts = []
      credit = slot_credit(scene)
      parts << PokeAccess::I18n.t(:mg_slot_credit, :n => credit.to_i) if credit
      w = scene.instance_variable_get(:@wager).to_i
      parts << PokeAccess::I18n.t(:mg_slot_wager, :n => w) if w > 0
      parts << PokeAccess::I18n.t(:mg_slot_paytable)
      parts.join(". ")
    end

    # Voices a spin's result: the lines played (the paying ones with their prize), the coins won, the bonus sign, the
    # replay or loss, then the credit; republishes the info key's line.
    # param before the credit counter before pbPayout ran
    # param wager the coins played, sampled before pbPayout (which zeroes @wager)
    def self.slot_payout(scene, before, wager = nil)
      after = slot_credit(scene)
      won = (before && after) ? (after.to_i - before.to_i) : 0
      replay = scene.instance_variable_get(:@replay) ? true : false
      parts, bonus = slot_board_lines(scene, wager)
      parts.push(PokeAccess::I18n.t(:mg_slot_won, :n => won)) if won > 0
      parts.push(PokeAccess::I18n.t(bonus == 2 ? :mg_slot_bonus_big : :mg_slot_bonus_reg)) if bonus > 0
      parts.push(PokeAccess::I18n.t(:mg_slot_replay_win)) if replay
      parts.push(PokeAccess::I18n.t(:mg_slot_lost)) if won <= 0 && !replay
      parts.push(PokeAccess::I18n.t(:mg_slot_credit, :n => after.to_i)) if after
      PokeAccess.speak(parts.join(". "), false, :menu)
      publish(scene, slot_info(scene))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # What one line pays as pbPayout counts it, [coins, bonus]: bonus 2 for three sevens of one colour, 1 for sevens
    # of both; three replays pay no coins (the free game is said apart).
    def self.slot_line_pay(syms)
      case syms
      when [1, 1, 1], [2, 2, 2] then [8, 0]
      when [3, 3, 3], [4, 4, 4] then [15, 0]
      when [5, 5, 5], [6, 6, 6] then [300, 2]
      when [7, 7, 7] then [0, 0]
      else
        if syms.all? { |s| s == 5 || s == 6 }
          [90, 1]
        elsif syms[0] == 0
          [syms[1] == 0 ? 4 : 2, 0]
        else
          [0, 0]
        end
      end
    end

    # [the lines the coins played as said, the bonus sign the best one lights (0 none)]: the centre, whose symbols
    # were said reel by reel, only when it pays, the others always, each paying line with its prize.
    def self.slot_board_lines(scene, wager = nil)
      wager = (wager.nil? ? scene.instance_variable_get(:@wager) : wager).to_i
      sprites = scene.instance_variable_get(:@sprites)
      cols = [1, 2, 3].map { |i| (sprites["reel#{i}"].showing rescue nil) }
      return [[], 0] if cols.any? { |c| !c.is_a?(Array) }
      played = wager >= 3 ? 5 : (wager == 2 ? 3 : 1)
      bonus = 0
      out = []
      SLOT_LINES[0, played].each do |key, rows|
        syms = (0..2).map { |reel| cols[reel][rows[reel]] }
        pay, sign = slot_line_pay(syms)
        bonus = sign if sign > bonus
        next if key == :mg_slot_row_mid && pay <= 0
        text = PokeAccess::I18n.t(key, :syms => syms.map { |s| slot_symbol(s) }.join(", "))
        out.push(pay > 0 ? "#{text}, #{PokeAccess::I18n.t(:mg_slot_pays, :n => pay)}" : text)
      end
      [out, bonus]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      [[], 0]
    end

    # Duel (PokemonDuel): a DuelWindow's duelist and HP, when the HP changes.
    def self.duel_hp(win)
      hp = (win.hp rescue nil)
      return if hp.nil?
      return if win.instance_variable_get(:@pa_duel_hp) == hp
      win.instance_variable_set(:@pa_duel_hp, hp)
      name = (win.name rescue nil).to_s
      PokeAccess.speak(PokeAccess::I18n.t(:mg_duel_hp, :who => name, :hp => hp), false, :menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Tile Puzzle board width. @tiles maps position -> tile id (solved: id == position, angle 0); positions >= w*h
    # are the off-board reserve of games 1/2. Tiles are said by 1-based id.
    def self.tp_board_w(scene)
      (scene.instance_variable_get(:@boardwidth) || 4).to_i
    end

    # Where square pos is: its row and column on the board or, past it, its side of the reserve (two panels of w/2
    # columns flanking the board, which pos % w tells apart) with its row and column there.
    def self.tp_where(w, h, pos)
      return PokeAccess::I18n.t(:mg_rowcol, :row => pos / w + 1, :col => pos % w + 1) if pos < w * h
      half = w / 2
      c = pos % w
      side = PokeAccess::I18n.t(c >= half ? :tp_reserve_right : :tp_reserve_left)
      "#{side}, #{PokeAccess::I18n.t(:mg_rowcol, :row => (pos % (w * h)) / w + 1, :col => (c >= half ? c - half : c) + 1)}"
    end

    # The cursor's cell: where it is, the tile on it, whether it is in place, its rotation when turned and, with the
    # puzzle help on, where it goes.
    def self.tp_cell(scene, pos)
      w = tp_board_w(scene)
      h = (scene.instance_variable_get(:@boardheight) || 4).to_i
      tiles = scene.instance_variable_get(:@tiles) || []
      angles = scene.instance_variable_get(:@angles) || []
      tile = tiles[pos]
      parts = [tp_where(w, h, pos)]
      if tile.nil? || tile < 0
        parts << PokeAccess::I18n.t(:tp_empty)
      else
        parts << PokeAccess::I18n.t(:tp_tile, :n => tile + 1)
        placed = pos < w * h && tile == pos && (angles[tile].to_i % 4) == 0
        parts << PokeAccess::I18n.t(:tp_placed) if placed
        ang = (angles[tile].to_i % 4)
        parts << PokeAccess::I18n.t(:tp_rotated, :deg => ang * 90) if ang != 0
        parts << tp_home(w, tile) if !placed && PokeAccess::Puzzles.assist?
      end
      parts.join(", ")
    end

    # Where a piece goes: the square of its own number.
    def self.tp_home(w, tile)
      PokeAccess::I18n.t(:tp_home, :row => tile / w + 1, :col => tile % w + 1)
    end

    # The piece in hand as said: its number and, when turned, how far.
    def self.tp_held(held, angles)
      ang = angles[held].to_i % 4
      text = PokeAccess::I18n.t(:tp_holding, :n => held + 1)
      ang == 0 ? text : "#{text}, #{PokeAccess::I18n.t(:tp_rotated, :deg => ang * 90)}"
    end

    # A piece as the board summary says it: its number, then in place (ok) or how far it is turned.
    def self.tp_piece(tile, angles, ok)
      text = PokeAccess::I18n.t(:tp_tile, :n => tile + 1)
      return "#{text} #{PokeAccess::I18n.t(:tp_placed)}" if ok
      ang = angles[tile].to_i % 4
      ang == 0 ? text : "#{text} #{PokeAccess::I18n.t(:tp_rotated, :deg => ang * 90)}"
    end

    # The whole board for the info key: each row's pieces (in place or turned, said so), the reserve's rows that hold
    # any, left panel first, the piece in hand, and how many are still out of place, the one in hand among them.
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
          tp_piece(t, angles, ok)
        end
        out << PokeAccess::I18n.t(:tp_board_row, :n => r + 1, :cells => cells.join(", "))
      end
      half = w / 2
      [[:tp_reserve_left, (0...half).to_a], [:tp_reserve_right, (half...w).to_a]].each do |side, cols|
        h.times do |r|
          spare = cols.map { |c| tiles[w * h + r * w + c] }
          next if spare.all? { |t| t.nil? || t < 0 }
          wrong += spare.count { |t| !t.nil? && t >= 0 }
          cells = spare.map { |t| (t.nil? || t < 0) ? PokeAccess::I18n.t(:tp_empty) : tp_piece(t, angles, false) }
          out << "#{PokeAccess::I18n.t(side)}, #{PokeAccess::I18n.t(:tp_board_row, :n => r + 1, :cells => cells.join(', '))}"
        end
      end
      held = scene.instance_variable_get(:@heldtile)
      if held && held.to_i >= 0
        wrong += 1
        out << tp_held(held.to_i, angles)
      end
      out << PokeAccess::I18n.t(:tp_wrong, :n => wrong)
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Voices the Tile Puzzle: the win once solved, else the cursor cell, the piece in hand with its turn and the legal
    # moves whenever that text changes (picking up and turning the piece in hand do not move the cursor).
    def self.tile_puzzle(scene)
      cur = (scene.instance_variable_get(:@sprites)["cursor"] rescue nil)
      return unless cur
      pos = cur.position.to_i
      solved = (scene.pbCheckWin rescue false)
      text = solved ? PokeAccess::I18n.t(:tp_solved) : tp_cell(scene, pos)
      unless solved
        held = scene.instance_variable_get(:@heldtile)
        text += ", " + tp_held(held.to_i, scene.instance_variable_get(:@angles) || []) if held && held.to_i >= 0
        dirs = tp_arrows(cur)
        text += ", " + PokeAccess::I18n.t(:tp_moves, :dirs => dirs) if dirs
      end
      sig = [pos, solved, text]
      return unless PokeAccess::Cursor.changed?(scene, :tp_cell, sig)
      PokeAccess.speak(text, true, :menu)
      publish(scene, tp_board(scene))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# The info key over the map while a minigame runs: the line it parked (Minigames.publish).
PokeAccess::Info.map_owner(:minigames) { PokeAccess::Minigames.board }
PokeAccess::Caches.register(:minigames) { PokeAccess::Minigames.unpublish }

# Voltorb Flip; hook_container because getInput opens the quit confirmation inside itself, whose reader the
# reentrancy guard would otherwise drop as nested.
PokeAccess::Hooks.after_hook("VoltorbFlip", :getInput, :hook_container => true) { |scene, _result, _args| PokeAccess::Minigames.voltorb_flip(scene) }
PokeAccess::Hooks.before_hook("VoltorbFlip", :pbShowAndDispose, :optional => true) { |scene, _a| PokeAccess::Minigames.vf_reveal(scene) }
# The boards parked for the info key are dropped as their screens start to close.
PokeAccess::Hooks.before_hook("VoltorbFlip", :pbEndScene, :optional => true) { |_s, _a| PokeAccess::Minigames.unpublish }
PokeAccess::Hooks.before_hook("TilePuzzleScene", :pbEndScene, :optional => true) { |_s, _a| PokeAccess::Minigames.unpublish }
PokeAccess::Hooks.after_hook("MiningGameCursor", :update) { |cursor, _result, _args| PokeAccess::Minigames.mining_cursor(cursor) }
PokeAccess::Hooks.before_hook("MiningGameScene", :pbStartScene) { |scene, _args| PokeAccess::Minigames.mine_scene = scene }
PokeAccess::Hooks.after_hook("MiningGameScene", :pbEndScene, :optional => true) do |_scene, _result, _args|
  PokeAccess::Minigames.mine_scene = nil
  PokeAccess::Minigames.unpublish
end
PokeAccess::Hooks.after_hook("MiningGameScene", :pbHit) do |scene, _result, _args|
  PokeAccess::Minigames.mining_hit(scene)
  PokeAccess::Minigames.mining_after_hit(scene)
  PokeAccess::Minigames.mining_wall(scene)
end

# Slot Machine (SlotMachineScene, its reels SlotMachineReel): the credit and keys as its loop starts, wager as coins
# go in, the reels as they start, each reel's symbol as it stops, and the win/loss once paid out. No-op where the
# classes are absent.
PokeAccess::Hooks.before_hook("SlotMachineScene", :pbMain, :optional => true) { |scene, _a| PokeAccess::Minigames.slot_open(scene) }
PokeAccess::Hooks.after_hook("SlotMachineScene", :update) do |scene, _r, _a|
  PokeAccess::Minigames.slot_wager(scene)
  PokeAccess::Minigames.slot_spin(scene)
end
PokeAccess::Hooks.after_hook("SlotMachineReel", :update) { |reel, _r, _a| PokeAccess::Minigames.slot_reel_update(reel) }
# pbPayout drains the payout into the credit and zeroes the wager: the credit is sampled on both sides, the wager
# before.
PokeAccess::Hooks.around_hook("SlotMachineScene", :pbPayout) do |scene, nxt, _a|
  before = PokeAccess::Minigames.slot_credit(scene)
  wager = scene.instance_variable_get(:@wager)
  begin; nxt.call; ensure; PokeAccess::Minigames.slot_payout(scene, before, wager); end
end
PokeAccess::Hooks.before_hook("SlotMachineScene", :pbEndScene, :optional => true) { |_s, _a| PokeAccess::Minigames.unpublish }

# Tile Puzzle (TilePuzzleScene), polled on the scene's per-frame update.
PokeAccess::Hooks.after_hook("TilePuzzleScene", :update) { |scene, _r, _a| PokeAccess::Minigames.tile_puzzle(scene) }

# Duel (DuelWindow): the refresh that runs on every change, duel_refresh (modern) or duelRefresh (pre-GameData).
PokeAccess::Hooks.after_hook("DuelWindow", :duel_refresh, :optional => true) { |win, _r, _a| PokeAccess::Minigames.duel_hp(win) }
PokeAccess::Hooks.after_hook("DuelWindow", :duelRefresh, :optional => true) { |win, _r, _a| PokeAccess::Minigames.duel_hp(win) }
