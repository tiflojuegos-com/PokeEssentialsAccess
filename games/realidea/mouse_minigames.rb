# Keyboard routes for realidea's mouse-only minigames. Each screen reads $mouse against a DISCRETE set
# of sprites and keeps its game logic in mouse-free methods, so the mod replaces the per-frame input
# method wholesale (around, never calling through): arrows move a mod-owned cursor, the game's own
# virtual accept/cancel buttons drive the same logic calls the click handlers made, and the keys the
# original input DID read (B close, A reset) are replicated. The engine's virtual buttons respect the
# player's own key mapping. Poketch is not here: the game ships it entirely inside a =begin block.
#
# Spoken labels are mod prose (the states exist on screen only as pictures); realidea is a declared
# single-language Spanish game, so the two literals mirrored from its code stay as the game wrote them.
module PokeAccess
  module ReaMouse
    # ---- Cockteles: four bottles, mix two, match the shown cocktail; 9 rounds. ----
    BOTTLES = [["rojo", :rmg_rojo], ["azul", :rmg_azul], ["amarillo", :rmg_amarillo], ["blanco", :rmg_blanco]]
    COCKTAILS = {
      "rojo2" => :rmg_ck_rojo2, "azul2" => :rmg_ck_azul2, "amarillo2" => :rmg_ck_amarillo2,
      "blanco2" => :rmg_ck_blanco2, "verde" => :rmg_verde, "morado" => :rmg_ck_morado,
      "naranja" => :rmg_ck_naranja, "rosa" => :rmg_ck_rosa, "pollo" => :rmg_ck_pollo,
      "celeste" => :rmg_ck_celeste
    }

    def self.cocktail_name(sel)
      k = COCKTAILS[sel.to_s]
      k ? PokeAccess::I18n.t(k) : sel.to_s
    end

    # Cocktails by keyboard: names the target cocktail when it changes (queued on the opening frame), LEFT/RIGHT
    # walk the bottle row, C pours the focused bottle; the verdict and score follow the game's own resolution.
    def self.ck_input(scene)
      sel = scene.instance_variable_get(:@seleccion)
      first = PokeAccess::Cursor.pending?(scene, :ck_target)
      if PokeAccess::Cursor.changed?(scene, :ck_target, sel.to_s) && sel
        PokeAccess.speak(PokeAccess::I18n.t(:rmg_ck_target, :name => cocktail_name(sel)), first)
      end
      idx = (scene.instance_variable_get(:@access_ck_idx) || 0).to_i
      moved = false
      if Input.trigger?(Input::LEFT)
        idx = (idx - 1) % BOTTLES.length
        moved = true
      elsif Input.trigger?(Input::RIGHT)
        idx = (idx + 1) % BOTTLES.length
        moved = true
      end
      if moved
        scene.instance_variable_set(:@access_ck_idx, idx)
        PokeAccess.speak(PokeAccess::I18n.t(BOTTLES[idx][1]), true)
      end
      if Input.trigger?(Input::C) && scene.instance_variable_get(:@intentos).to_i < 9
        color = BOTTLES[idx][0]
        before_v = scene.instance_variable_get(:@victorias).to_i
        before_d = scene.instance_variable_get(:@derrotas).to_i
        player = scene.instance_variable_get(:@player)
        first = player.is_a?(Array) && player.empty?
        player.push(color)
        scene.send(:colorescopa)
        if first
          PokeAccess.speak(PokeAccess::I18n.t(:rmg_ck_poured, :name => PokeAccess::I18n.t(BOTTLES[idx][1])), true)
        else
          v = scene.instance_variable_get(:@victorias).to_i
          d = scene.instance_variable_get(:@derrotas).to_i
          hit = v > before_v
          PokeAccess.speak(PokeAccess::I18n.t(hit ? :rmg_ck_hit : :rmg_ck_miss, :v => v, :n => v + d, :tot => 9), true)
        end
      end
    rescue StandardError
      nil
    end

    # ---- Tresenraya: 3x3 board, the enemy answers inside the same frame. ----
    def self.ttt_cell(scene, r, c)
      return :yours if (scene.instance_variable_get(:@playpos)[r][c] rescue false)
      return :enemy if (scene.instance_variable_get(:@enempos)[r][c] rescue false)
      :free
    end

    def self.ttt_say_cell(scene, r, c)
      st = ttt_cell(scene, r, c)
      k = st == :yours ? :rmg_ttt_yours : (st == :enemy ? :rmg_ttt_enemy : :rmg_ttt_free)
      PokeAccess.speak(PokeAccess::I18n.t(:rmg_ttt_cell, :row => r, :col => c, :state => PokeAccess::I18n.t(k)), true)
    end

    # Tic-tac-toe by keyboard: arrows move a cell cursor over the 3x3 board, C plays the focused cell, and the
    # enemy's reply is announced by the cell it took.
    def self.ttt_input(scene)
      r = (scene.instance_variable_get(:@access_ttt_r) || 2).to_i
      c = (scene.instance_variable_get(:@access_ttt_c) || 2).to_i
      nr, nc = r, c
      nr -= 1 if Input.trigger?(Input::UP)
      nr += 1 if Input.trigger?(Input::DOWN)
      nc -= 1 if Input.trigger?(Input::LEFT)
      nc += 1 if Input.trigger?(Input::RIGHT)
      nr = 1 if nr < 1; nr = 3 if nr > 3
      nc = 1 if nc < 1; nc = 3 if nc > 3
      if nr != r || nc != c
        scene.instance_variable_set(:@access_ttt_r, nr)
        scene.instance_variable_set(:@access_ttt_c, nc)
        ttt_say_cell(scene, nr, nc)
      end
      r, c = nr, nc
      if Input.trigger?(Input::C) && scene.instance_variable_get(:@turno) == 0 &&
         ttt_cell(scene, r, c) == :free
        scene.instance_variable_get(:@sprites)["hueco#{r}_#{c}"].setBitmap("Graphics/Pictures/Tresenraya/cruz")
        scene.instance_variable_get(:@playpos)[r][c] = true
        scene.send(:comprobar)
        scene.instance_variable_set(:@turno, 1)
        PokeAccess.speak(PokeAccess::I18n.t(:rmg_ttt_placed, :row => r, :col => c), true)
      end
      if scene.instance_variable_get(:@turno) == 1 && scene.instance_variable_get(:@resultado) == 0
        before = snapshot_enemy(scene)
        scene.send(:turnoenemigo)
        played = enemy_diff(scene, before)
        PokeAccess.speak(PokeAccess::I18n.t(:rmg_ttt_enemy_move, :row => played[0], :col => played[1]), false) if played
      end
      scene.instance_variable_set(:@cerrar, 1) if Input.trigger?(Input::B)
    rescue StandardError
      nil
    end

    def self.snapshot_enemy(scene)
      e = scene.instance_variable_get(:@enempos)
      out = {}
      (1..3).each { |i| (1..3).each { |j| out[[i, j]] = (e[i][j] rescue false) } }
      out
    end

    def self.enemy_diff(scene, before)
      e = scene.instance_variable_get(:@enempos)
      (1..3).each do |i|
        (1..3).each { |j| return [i, j] if (e[i][j] rescue false) && !before[[i, j]] }
      end
      nil
    end

    # ---- Menuminior: already keyboard-driven, only mute. Difficulty rows are pictures. ----
    MM_ROWS = [:rmg_mm_easy, :rmg_mm_normal, :rmg_mm_hard]

    # param painted the rows the game's input painted this frame (the help overlay, on the frame it opens)
    def self.mm_after(scene, painted = nil)
      if scene.instance_variable_get(:@info).to_i == 1
        PokeAccess::Cursor.announce(scene, :mm_help, 1, true) { PokeAccess::PaintCapture.text(painted) }
        return
      end
      PokeAccess::Cursor.reset(scene, :mm_help)
      sel = scene.instance_variable_get(:@selec).to_i
      if PokeAccess::Cursor.changed?(scene, :mm_sel, sel) && MM_ROWS[sel]
        PokeAccess.speak(PokeAccess::I18n.t(MM_ROWS[sel]), true)
      end
    rescue StandardError
      nil
    end

    # ---- Miniorgame board: 10x9 falling grid; a cell speaks its colour and group size. ----
    MG_COLORS = {
      "miniorrojo" => :rmg_rojo, "minioramarillo" => :rmg_amarillo, "miniorverde" => :rmg_verde,
      "miniorazul" => :rmg_azul, "miniorlila" => :rmg_lila
    }

    def self.mg_cell_text(scene, r, c)
      m = (scene.instance_variable_get(:@miniorsmatrix)[r][c] rescue nil)
      return PokeAccess::I18n.t(:rmg_mg_empty, :row => r + 1, :col => c + 1) if m.nil?
      ck = MG_COLORS[m.color.to_s]
      cname = ck ? PokeAccess::I18n.t(ck) : m.color.to_s
      n = (scene.send(:contar_vecinos, r, c, m.color) rescue 1)
      PokeAccess::I18n.t(:rmg_mg_cell, :color => cname, :n => n, :row => r + 1, :col => c + 1)
    end

    # Minior board by keyboard: B closes and A resets (the game's own keys), arrows move a cell cursor, C bursts
    # the focused group; a cell names its colour and group size, and the score follows a burst.
    def self.mg_input(scene)
      scene.instance_variable_set(:@cerrar, 1) if Input.trigger?(Input::B)
      scene.instance_variable_set(:@reset, 1) if Input.trigger?(Input::A)
      r = (scene.instance_variable_get(:@access_mg_r) || 9).to_i
      c = (scene.instance_variable_get(:@access_mg_c) || 0).to_i
      nr, nc = r, c
      nr -= 1 if Input.trigger?(Input::UP)
      nr += 1 if Input.trigger?(Input::DOWN)
      nc -= 1 if Input.trigger?(Input::LEFT)
      nc += 1 if Input.trigger?(Input::RIGHT)
      nr = 0 if nr < 0; nr = 9 if nr > 9
      nc = 0 if nc < 0; nc = 8 if nc > 8
      if nr != r || nc != c
        scene.instance_variable_set(:@access_mg_r, nr)
        scene.instance_variable_set(:@access_mg_c, nc)
        PokeAccess.speak(mg_cell_text(scene, nr, nc), true)
      end
      r, c = nr, nc
      if Input.trigger?(Input::C)
        m = (scene.instance_variable_get(:@miniorsmatrix)[r][c] rescue nil)
        if m && (scene.send(:contar_vecinos, r, c, m.color) rescue 0) > 1
          scene.send(:buscarvecinos, r, c, m.color)
          scene.instance_variable_set(:@access_mg_burst, true)
        else
          PokeAccess.speak(PokeAccess::I18n.t(:rmg_mg_no_group), true)
        end
      end
      if scene.instance_variable_get(:@access_mg_burst)
        tot = scene.instance_variable_get(:@total).to_i
        cnt = scene.instance_variable_get(:@count).to_i
        if PokeAccess::Cursor.changed?(scene, :mg_score, [tot, cnt]) && tot > 0
          scene.instance_variable_set(:@access_mg_burst, nil)
          PokeAccess.speak(PokeAccess::I18n.t(:rmg_mg_score, :pts => tot, :left => cnt), false)
        end
      end
    rescue StandardError
      nil
    end


    # ---- Perlita: a shell game. Three identical bags shuffle and the player must follow WHERE the
    # asked pearl's bag ended up. Selecting by bag NAME would dissolve the game, so the route mirrors
    # the sighted challenge exactly: the round announces which pearl goes where BEFORE the bags close
    # (the screen shows that too), every shuffle is spoken as a POSITION crossing, and the pick is by
    # position -- the tracking stays in the player's head, where the game put it. ----
    PL_BAGS = { "sacoazul" => ["azul", :rmg_pl_azul], "sacoamarillo" => ["amarilla", :rmg_pl_amarilla],
                "sacorojo" => ["roja", :rmg_pl_roja] }
    PL_POS = [:rmg_pl_left, :rmg_pl_center, :rmg_pl_right]

    def self.pl_sorted(scene)
      sprites = scene.instance_variable_get(:@sprites)
      PL_BAGS.keys.map { |k| [sprites[k], k] }.select { |sp, _k| sp }.sort_by { |sp, _k| sp.x }
    end

    def self.pl_target(scene)
      sk = scene.instance_variable_get(:@saquito).to_s
      pair = PL_BAGS.values.find { |resp, _key| resp == sk }
      color = pair ? PokeAccess::I18n.t(pair[1]) : sk
      PokeAccess.speak(PokeAccess::I18n.t(:rmg_pl_target, :color => color), true)
      order = pl_sorted(scene)
      if order.length == 3
        names = order.map { |_sp, k| PokeAccess::I18n.t(PL_BAGS[k][1]) }
        PokeAccess.speak(PokeAccess::I18n.t(:rmg_pl_layout, :l => names[0], :c => names[1], :r => names[2]), false)
      end
    rescue StandardError
      nil
    end

    def self.pl_swap(scene, before)
      after_x = {}
      pl_sorted(scene).each { |sp, k| after_x[k] = sp.x }
      moved = before.keys.select { |k| before[k] != after_x[k] }
      return unless moved.length == 2
      ranks = before.values.sort
      a = ranks.index(before[moved[0]])
      b = ranks.index(before[moved[1]])
      a, b = b, a if a > b
      PokeAccess.speak(PokeAccess::I18n.t(:rmg_pl_swap, :a => PokeAccess::I18n.t(PL_POS[a]),
                                          :b => PokeAccess::I18n.t(PL_POS[b])), false)
    rescue StandardError
      nil
    end

    # Shell game by keyboard: LEFT/RIGHT walk the three bags by POSITION (the shuffle was announced as swaps, so
    # the player tracks where the pearl went), C opens the focused bag.
    def self.pl_input(scene)
      scene.instance_variable_get(:@sprites)["bocadillo"].visible = true
      scene.instance_variable_get(:@sprites)["bolabocadillo"].visible = true
      idx = (scene.instance_variable_get(:@access_pl_idx) || 1).to_i
      moved = false
      if Input.trigger?(Input::LEFT)
        idx -= 1; moved = true
      elsif Input.trigger?(Input::RIGHT)
        idx += 1; moved = true
      end
      idx = 0 if idx < 0; idx = 2 if idx > 2
      if moved
        scene.instance_variable_set(:@access_pl_idx, idx)
        PokeAccess.speak(PokeAccess::I18n.t(PL_POS[idx]), true)
      end
      if Input.trigger?(Input::C)
        order = pl_sorted(scene)
        pick = order[idx]
        if pick
          before_v = scene.instance_variable_get(:@victorias).to_i
          scene.instance_variable_set(:@respuesta, PL_BAGS[pick[1]][0])
          scene.send(:abrirsaquito)
          v = scene.instance_variable_get(:@victorias).to_i
          d = scene.instance_variable_get(:@derrotas).to_i
          hit = v > before_v
          PokeAccess.speak(PokeAccess::I18n.t(hit ? :rmg_ck_hit : :rmg_ck_miss, :v => v, :n => v + d, :tot => 5), true)
        end
      end
    rescue StandardError
      nil
    end

    # ---- Unowngame: a balance of Roman-numeral Unown; equalise both sides. The game drags with the
    # mouse, but only the SIDE of the split matters, so the keyboard route moves a piece across in one
    # atomic frame (pick, relocate, score) and the drag never enters into it. ----
    UNOWN = [["M", 3, 1000], ["D", 4, 500], ["C", 4, 100], ["L", 2, 50], ["X", 1, 10], ["V", 2, 5], ["I", 2, 1]]

    def self.un_pieces(scene)
      sprites = scene.instance_variable_get(:@sprites)
      out = []
      UNOWN.each do |letter, count, value|
        count.times do |i|
          key = (letter == "X") ? "X" : "#{letter}#{i}"
          sp = sprites[key]
          out.push([key, letter, value, sp]) if sp && !(sp.disposed? rescue false)
        end
      end
      out
    end

    def self.un_side(scene, sp)
      lim = scene.instance_variable_get(:@limite).to_i
      sp.x >= lim ? :right : :left
    end

    def self.un_say(scene, piece)
      side = un_side(scene, piece[3]) == :right ? :rmg_un_right : :rmg_un_left
      PokeAccess.speak(PokeAccess::I18n.t(:rmg_un_piece, :letter => piece[1], :value => piece[2],
                                          :side => PokeAccess::I18n.t(side)), true)
    end

    # Unown puzzle by keyboard: LEFT/UP and RIGHT/DOWN walk the pieces, C picks up or drops the focused piece,
    # and the score is recomputed after a move.
    def self.un_input(scene)
      pieces = un_pieces(scene)
      return if pieces.empty?
      idx = (scene.instance_variable_get(:@access_un_idx) || 0).to_i % pieces.length
      moved = false
      if Input.trigger?(Input::LEFT) || Input.trigger?(Input::UP)
        idx = (idx - 1) % pieces.length
        moved = true
      elsif Input.trigger?(Input::RIGHT) || Input.trigger?(Input::DOWN)
        idx = (idx + 1) % pieces.length
        moved = true
      end
      if moved
        scene.instance_variable_set(:@access_un_idx, idx)
        un_say(scene, pieces[idx])
      end
      if Input.trigger?(Input::C)
        piece = pieces[idx]
        sp = piece[3]
        lim = scene.instance_variable_get(:@limite).to_i
        scene.instance_variable_set(:@seleccion, sp)
        scene.instance_variable_set(:@guardarx, sp.x)
        sp.x = (sp.x >= lim) ? (lim - 120) : (lim + 120)
        scene.send(:puntuacion)
        scene.instance_variable_set(:@seleccion, nil)
        p1 = scene.instance_variable_get(:@puntuacion1).to_i
        p2 = scene.instance_variable_get(:@puntuacion2).to_i
        PokeAccess.speak(PokeAccess::I18n.t(:rmg_un_moved, :letter => piece[1], :right => p1, :left => p2), true)
      end
      if Input.trigger?(Input::A)
        p1 = scene.instance_variable_get(:@puntuacion1).to_i
        p2 = scene.instance_variable_get(:@puntuacion2).to_i
        PokeAccess.speak(PokeAccess::I18n.t(:rmg_un_totals, :right => p1, :left => p2), true)
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("realidea") do
  around("Cockteles", :input) { |s, _nxt, _a| PokeAccess::ReaMouse.ck_input(s) }
  around("Tresenraya", :input) { |s, _nxt, _a| PokeAccess::ReaMouse.ttt_input(s) }
  around("Miniorgame", :input) { |s, _nxt, _a| PokeAccess::ReaMouse.mg_input(s) }
  around("Unowngame", :input) do |s, _nxt, _a|
    PokeAccess::ReaMouse.un_input(s)
  end
  around("Perlita", :input) { |s, _nxt, _a| PokeAccess::ReaMouse.pl_input(s) }
  after("Perlita", :escogersaquito) { |s, _r, _a| PokeAccess::ReaMouse.pl_target(s) }
  around("Perlita", :moversaquitos) do |s, nxt, _a|
    before = {}
    PokeAccess::ReaMouse.pl_sorted(s).each { |sp, k| before[k] = sp.x }
    begin
      nxt.call
    ensure
      PokeAccess::ReaMouse.pl_swap(s, before)
    end
  end
  around("Menuminior", :input) do |s, nxt, _a|
    PokeAccess::PaintCapture.arm(:rmg_mm_help)
    begin
      nxt.call
    ensure
      PokeAccess::ReaMouse.mm_after(s, PokeAccess::PaintCapture.take(:rmg_mm_help))
    end
  end
end
