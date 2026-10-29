# Realidea's mouse-only minigames played by keyboard (games/realidea/mouse_minigames.rb): the arrows move the mod's
# cursor, the accept key makes the game's calls a click made, and every move, pick and result is said, as is the goal
# a Minior round paints as it starts.

# A sprite as these minigames place them: a position, a bitmap set by path, shown or hidden, and disposed of.
class ReaMinigameSprite
  attr_accessor :x, :y, :visible
  attr_reader :bitmap

  def initialize(x = 0, y = 0)
    @x = x
    @y = y
    @visible = false
    @disposed = false
  end

  def setBitmap(path); @bitmap = path; end
  def dispose; @disposed = true; end
  def disposed?; @disposed; end
end

# Cockteles: four bottles, two of them mixed into the cocktail shown (@seleccion), nine rounds. Its input answers only
# clicks, besides counting three wins on the accept and back keys, a leftover the mod's keys must never reach;
# colorescopa paints the glass for one bottle and resolves two by the game's mixes, then shows the next cocktail (the
# one rand would draw) while rounds remain.
class Cockteles
  MIXES = { %w[rojo rojo] => "rojo2", %w[azul azul] => "azul2", %w[amarillo amarillo] => "amarillo2",
            %w[blanco blanco] => "blanco2", %w[azul rojo] => "morado", %w[amarillo rojo] => "naranja",
            %w[blanco rojo] => "rosa", %w[amarillo blanco] => "pollo", %w[azul blanco] => "celeste",
            %w[amarillo azul] => "verde" }

  attr_accessor :intentos
  attr_reader :player, :victorias, :derrotas, :copa

  def initialize(target, following = "verde")
    @seleccion = target
    @following = following
    @player = []
    @intentos = 0
    @victorias = 0
    @derrotas = 0
  end

  def input
    @victorias = 3 if Input.trigger?(Input::B) || Input.trigger?(Input::C)
  end

  def colorescopa
    @copa = @player.length == 1 ? @player[0] : MIXES[@player.sort]
    return if @player.length == 1
    if @seleccion == @copa then @victorias += 1 else @derrotas += 1 end
    @intentos = @victorias + @derrotas
    return unless @intentos < 9
    @seleccion = @following
    @player = []
  end
end

# Tresenraya: a 3x3 board, rows and columns 1 to 3, the player's crosses in @playpos and the rival's circles in
# @enempos. comprobar sets @resultado 2 on a line of crosses, turnoenemigo takes the centre or else the first free cell
# and hands the turn back, and input answers only clicks.
class Tresenraya
  CELLS = [1, 2, 3].product([1, 2, 3])
  LINES = [1, 2, 3].map { |i| [[i, 1], [i, 2], [i, 3]] } + [1, 2, 3].map { |j| [[1, j], [2, j], [3, j]] } +
          [[[1, 1], [2, 2], [3, 3]], [[3, 1], [2, 2], [1, 3]]]

  attr_reader :playpos, :enempos, :sprites, :turno, :cerrar

  def initialize(turno = 0)
    @turno = turno
    @resultado = 0
    @cerrar = 0
    @playpos = Array.new(4) { Array.new(4, false) }
    @enempos = Array.new(4) { Array.new(4, false) }
    @sprites = {}
    CELLS.each { |i, j| @sprites["hueco#{i}_#{j}"] = ReaMinigameSprite.new }
  end

  def input
    CELLS.each { |i, j| $mouse.leftClick?(@sprites["hueco#{i}_#{j}"]) }
  end

  def comprobar
    @resultado = 2 if LINES.any? { |line| line.all? { |i, j| @playpos[i][j] } }
  end

  def turnoenemigo
    cell = ([[2, 2]] + CELLS).find { |i, j| !@playpos[i][j] && !@enempos[i][j] }
    @enempos[cell[0]][cell[1]] = true if cell
    @turno = 0
  end
end

# A minior of the board: its colour, and whether a burst marked it.
class ReaMinior
  attr_reader :color
  attr_accessor :selected

  def initialize(color)
    @color = color
    @selected = false
  end
end

# Miniorgame: the 10x9 board of miniors, row 0 at the top, built from rows of colour letters (COLORS). contar_vecinos
# sizes the group of one colour a cell belongs to, buscarvecinos marks it, and deleteselected, which the game's loop
# runs right after input, takes the marked ones away, scoring them 400, 800, 1600... and counting the ones left. Its
# input answers clicks, back (close) and A (start again). diff starts a round of a difficulty (0 to 2) through
# repetir, the game's loop, here two of its frames: the round's goal and both counters painted, then input.
class Miniorgame
  COLORS = { "r" => "miniorrojo", "a" => "minioramarillo", "v" => "miniorverde", "z" => "miniorazul",
             "l" => "miniorlila", "n" => "miniornegro", "g" => "miniorgris" }
  GOALS = ["¡Puedes dejarte hasta 5 Minior!", "¡Puedes dejarte hasta 15 Minior!", "¡Puedes dejarte hasta 10 Minior!"]

  attr_reader :miniorsmatrix, :total, :count, :cerrar, :reset

  def initialize(rows)
    @miniorsmatrix = rows.map { |row| row.chars.map { |ch| ReaMinior.new(COLORS[ch]) } }
    @total = 0
    @count = 90
    @cerrar = 0
    @reset = 0
  end

  def diff(dificultad)
    @dificultad = dificultad
    repetir
  end

  def repetir
    2.times do
      Graphics.update
      Input.update
      drawTextEx(nil, 365, 20, 150, 2, GOALS[@dificultad])
      drawTextEx(nil, 365, 95, 100, 2, "Pts: #{@total}")
      drawTextEx(nil, 365, 125, 120, 1, "Restantes: #{@count}")
      input
      deleteselected
    end
  end

  def input
    @cerrar = 1 if Input.trigger?(Input::B)
    @reset = 1 if Input.trigger?(Input::A)
    @miniorsmatrix.flatten.compact.each { |m| $mouse.leftClick?(m) }
  end

  def contar_vecinos(i, j, color, _visited = [])
    group(i, j, color).length
  end

  def buscarvecinos(i, j, color, _visited = [])
    group(i, j, color).each { |r, c| @miniorsmatrix[r][c].selected = true }
  end

  def deleteselected
    contador = 200
    @miniorsmatrix.each do |row|
      row.each_index do |c|
        next unless row[c] && row[c].selected
        row[c] = nil
        contador *= 2
        @total += contador
      end
    end
    @count = @miniorsmatrix.flatten.compact.length
  end

  private

  def group(i, j, color)
    seen = []
    todo = [[i, j]]
    until todo.empty?
      r, c = todo.pop
      m = r.between?(0, 9) && c.between?(0, 8) ? @miniorsmatrix[r][c] : nil
      next if m.nil? || m.color != color || seen.include?([r, c])
      seen.push([r, c])
      todo.concat([[r - 1, c], [r + 1, c], [r, c - 1], [r, c + 1]])
    end
    seen
  end
end

# Menuminior: the difficulty menu, rows 0 to 2 in @selec, moved by up and down and wrapping; A paints the help over it
# (@info 1) and back takes the help away. Already keyboard-driven, the mod only reads it.
class Menuminior
  HELP = "¡Haz click sobre los Miniors que estén al lado de otros del mismo color!"

  def initialize
    @selec = 0
    @info = 0
  end

  def input
    if Input.trigger?(Input::DOWN) && @info == 0
      @selec += 1
      @selec = 0 if @selec == 3
    end
    if Input.trigger?(Input::UP) && @info == 0
      @selec -= 1
      @selec = 2 if @selec == -1
    end
    @info = 0 if Input.trigger?(Input::B)
    return unless Input.trigger?(Input::A)
    @info = 1
    drawTextEx(nil, 130, 15, 280, 11, HELP)
  end
end

# Unowngame: Roman-numeral Unown to balance across the split at x 225 (@limite). puntuacion1 counts both sides as it
# opens, puntuacion moves the value of the piece held in @seleccion to the side it now stands on, input answers only
# clicks, and actu_pass is one pass of the game's loop: the held piece dragged to the mouse, then input.
class Unowngame
  VALUES = { "M" => 1000, "D" => 500, "C" => 100, "L" => 50, "X" => 10, "V" => 5, "I" => 1 }
  COUNTS = { "M" => 3, "C" => 4, "D" => 4, "L" => 2, "I" => 2, "V" => 2 }
  MOUSE_X = 40

  attr_reader :sprites

  def initialize
    @limite = 225
    @sprites = {}
    COUNTS.each { |letter, n| n.times { |i| @sprites["#{letter}#{i}"] = ReaMinigameSprite.new(100, 50) } }
    @sprites["X"] = ReaMinigameSprite.new(300, 50)
    @puntuacion1 = 0
    @puntuacion2 = 0
    puntuacion1
  end

  def totals; [@puntuacion1, @puntuacion2]; end

  def actu_pass
    @seleccion.x = MOUSE_X - 25 if @seleccion
    input
  end

  def input
    @sprites.each_value { |sp| $mouse.leftClick?(sp) }
  end

  def puntuacion1
    @sprites.each do |key, sp|
      if sp.x >= @limite then @puntuacion1 += VALUES[key[0, 1]] else @puntuacion2 += VALUES[key[0, 1]] end
    end
  end

  def puntuacion
    @sprites.each do |key, sp|
      next unless @seleccion.equal?(sp)
      v = VALUES[key[0, 1]]
      if sp.x >= @limite
        @puntuacion1 += v
        @puntuacion2 -= v
      else
        @puntuacion1 -= v
        @puntuacion2 += v
      end
    end
  end
end

# Perlita: three bags over their pearls (x 60, 210 and 360). cerrarsaquitos hides the bubble with the pearl to find
# and closes the bags, then runs escogersaquito, which draws that pearl; moversaquitos hides the bubble and crosses two
# bags; abrirsaquito counts the bag in @respuesta against the pearl and, while fewer than five rounds are played,
# closes the bags again and crosses them two to five times by the wins. The pearls and the crossings come from the
# queues a test sets, else at random as rand draws them. input shows the bubble and answers only clicks, besides
# counting three wins on the accept key, a leftover the mod's keys must never reach.
class Perlita
  PEARLS = %w[azul amarilla roja]
  CROSSINGS = [%w[sacorojo sacoazul], %w[sacorojo sacoamarillo], %w[sacoazul sacoamarillo]]

  attr_accessor :victorias, :derrotas
  attr_reader :sprites
  attr_writer :pearls, :crossings

  def initialize
    @victorias = 0
    @derrotas = 0
    @pearls = []
    @crossings = []
    @sprites = { "sacoazul" => ReaMinigameSprite.new(60, 100), "sacoamarillo" => ReaMinigameSprite.new(210, 100),
                 "sacorojo" => ReaMinigameSprite.new(360, 100), "bocadillo" => ReaMinigameSprite.new(200, 240),
                 "bolabocadillo" => ReaMinigameSprite.new(295, 270) }
  end

  def cerrarsaquitos
    @sprites["bocadillo"].visible = false
    @sprites["bolabocadillo"].visible = false
    escogersaquito
  end

  def escogersaquito
    @saquito = @pearls.shift || PEARLS[rand(3)]
  end

  def moversaquitos
    @sprites["bocadillo"].visible = false
    @sprites["bolabocadillo"].visible = false
    a, b = (@crossings.shift || CROSSINGS[rand(3)]).map { |k| @sprites[k] }
    a.x, b.x = b.x, a.x
  end

  def abrirsaquito
    if @respuesta == @saquito then @victorias += 1 else @derrotas += 1 end
    @intentos = @victorias + @derrotas
    return unless @intentos < 5
    cerrarsaquitos
    [2, 3, 4, 5, 5][@victorias].times { moversaquitos }
  end

  def input
    @sprites["bocadillo"].visible = true
    @sprites["bolabocadillo"].visible = true
    @victorias = 3 if Input.trigger?(Input::C)
  end
end

mouse_minigames = File.join(Harness::ROOT, "games", "realidea", "mouse_minigames.rb")
eval(Harness.source(mouse_minigames), TOPLEVEL_BINDING, mouse_minigames)

class RealideaMouseMinigamesTest < PokeAccessTest
  # The game's cocktails, as selecolor draws them, with the mod's word for each.
  COCKTAILS = { "rojo2" => :rmg_ck_rojo2, "azul2" => :rmg_ck_azul2, "amarillo2" => :rmg_ck_amarillo2,
                "blanco2" => :rmg_ck_blanco2, "verde" => :rmg_verde, "morado" => :rmg_ck_morado,
                "naranja" => :rmg_ck_naranja, "rosa" => :rmg_ck_rosa, "pollo" => :rmg_ck_pollo,
                "celeste" => :rmg_ck_celeste }
  # A board of green miniors with a red group of three on the bottom row's left and a lone yellow one above it.
  BOARD = ["vvvvvvvvv"] * 8 + ["avvvvvvvv", "rrrvvvvvv"]
  # A board of filler miniors (grey, a colour the game never draws) with a red and a blue pair on its bottom row.
  PAIRS = ["ggggggggg"] * 9 + ["rrgzzgggg"]
  # A shell game's draws, as rand makes them: the pearls of three rounds, and the crossings of the opening (which leave
  # the blue bag on the right, yellow left, red centre) and of the round after a win (red centre, blue left, yellow
  # right).
  PEARL_DRAWS = %w[azul roja amarilla]
  CROSSING_DRAWS = [%w[sacoazul sacoamarillo], %w[sacorojo sacoazul],
                    %w[sacorojo sacoamarillo], %w[sacoazul sacoamarillo], %w[sacorojo sacoazul]]

  test "the cocktail to make is said on the opening frame, interrupting, and not again while it stands" do
    bar = Cockteles.new("morado")
    frame(bar)
    frame(bar)
    assert_equal [[t(:rmg_ck_target, :name => t(:rmg_ck_morado)), true]], SpeakCapture.log
  end

  test "every cocktail the game draws is named with the mod's word" do
    COCKTAILS.each do |drawn, word|
      SpeakCapture.clear
      frame(Cockteles.new(drawn))
      assert_equal [t(:rmg_ck_target, :name => t(word))], SpeakCapture.lines, "for #{drawn}"
    end
  end

  test "the cocktail is named in the player's language, and one the mod has no word for as the game names it" do
    PokeAccess::Config.language = :en
    { "morado" => t(:rmg_ck_morado), "turquesa" => "turquesa" }.each do |drawn, word|
      SpeakCapture.clear
      frame(Cockteles.new(drawn))
      assert_equal [t(:rmg_ck_target, :name => word)], SpeakCapture.lines, "for #{drawn}"
    end
  end

  test "right walks the four bottles in the game's order and wraps back to the first" do
    bar = opened_bar
    4.times { frame(bar, Input::RIGHT) }
    assert_equal [[t(:rmg_azul), true], [t(:rmg_amarillo), true], [t(:rmg_blanco), true], [t(:rmg_rojo), true]],
                 SpeakCapture.log
  end

  test "left from the first bottle wraps to the last" do
    bar = opened_bar
    frame(bar, Input::LEFT)
    assert_equal [[t(:rmg_blanco), true]], SpeakCapture.log
  end

  test "the accept key pours the focused bottle into the game's glass and asks for the second" do
    bar = opened_bar
    frame(bar, Input::RIGHT)
    SpeakCapture.clear
    frame(bar, Input::C)
    assert_equal [["azul"], "azul"], [bar.player, bar.copa], "the bottle in the game's glass, painted"
    assert_equal [[t(:rmg_ck_poured, :name => t(:rmg_azul)), true]], SpeakCapture.log
  end

  test "the second bottle resolves the round through the game's mix, a right one said as a hit" do
    bar = opened_bar
    pour(bar, Input::RIGHT)
    SpeakCapture.clear
    pour(bar, Input::LEFT)
    assert_equal [[t(:rmg_rojo), true], [t(:rmg_ck_hit, :v => 1, :n => 1, :tot => 9), true]], SpeakCapture.log
  end

  test "a wrong mix is said as a miss with the rounds played" do
    bar = opened_bar
    pour(bar)
    SpeakCapture.clear
    pour(bar)
    assert_equal [[t(:rmg_ck_miss, :v => 0, :n => 1, :tot => 9), true]], SpeakCapture.log
  end

  test "the cocktail verdict counts every round the game has played" do
    bar = opened_bar
    2.times { pour(bar) }
    frame(bar)
    pour(bar, Input::RIGHT, Input::RIGHT)
    SpeakCapture.clear
    pour(bar, Input::RIGHT)
    assert_equal [[t(:rmg_blanco), true], [t(:rmg_ck_miss, :v => 0, :n => 2, :tot => 9), true]], SpeakCapture.log
  end

  test "the next round's cocktail is said after the verdict, queued behind it" do
    bar = opened_bar
    2.times { pour(bar) }
    SpeakCapture.clear
    frame(bar)
    assert_equal [[t(:rmg_ck_target, :name => t(:rmg_verde)), false]], SpeakCapture.log
  end

  test "once the nine rounds are played the accept key pours nothing" do
    bar = opened_bar
    bar.intentos = 9
    frame(bar, Input::C)
    assert_equal [], bar.player, "the glass stays empty"
    assert_nothing_spoken
  end

  test "the accept key never reaches the cocktail game's own input, which would count three wins" do
    bar = opened_bar
    frame(bar, Input::C)
    assert_equal 0, bar.victorias
  end

  test "the tic-tac-toe cursor starts on the centre and each arrow says the cell it lands on and whose it is" do
    board = Tresenraya.new
    board.playpos[3][2] = true
    board.enempos[2][1] = true
    [Input::DOWN, Input::LEFT, Input::UP].each { |k| frame(board, k) }
    assert_equal [[ttt_cell(3, 2, :rmg_ttt_yours), true], [ttt_cell(3, 1, :rmg_ttt_free), true],
                  [ttt_cell(2, 1, :rmg_ttt_enemy), true]], SpeakCapture.log
  end

  test "the tic-tac-toe cursor stops at each edge of the board without a word" do
    { Input::UP => [1, 2], Input::DOWN => [3, 2], Input::LEFT => [2, 1], Input::RIGHT => [2, 3] }.each do |key, (r, c)|
      board = Tresenraya.new
      SpeakCapture.clear
      2.times { frame(board, key) }
      assert_equal [ttt_cell(r, c, :rmg_ttt_free)], SpeakCapture.lines, "pressing #{key} twice"
    end
  end

  test "the accept key puts a cross on the focused cell through the game's board, and the rival's answer follows" do
    board = Tresenraya.new
    frame(board, Input::C)
    assert_equal [[t(:rmg_ttt_placed, :row => 2, :col => 2), true],
                  [t(:rmg_ttt_enemy_move, :row => 1, :col => 1), false]], SpeakCapture.log
    assert_equal [true, true, 0], [board.playpos[2][2], board.enempos[1][1], board.turno], "the game's board and turn"
    assert_equal "Graphics/Pictures/Tresenraya/cruz", board.sprites["hueco2_2"].bitmap, "painted as the game paints it"
  end

  test "a cross that completes a line ends the game: the rival does not answer" do
    board = Tresenraya.new
    board.playpos[1][2] = true
    board.playpos[3][2] = true
    frame(board, Input::C)
    assert_equal [[t(:rmg_ttt_placed, :row => 2, :col => 2), true]], SpeakCapture.log
  end

  test "the accept key on a taken cell places nothing" do
    [:playpos, :enempos].each do |side|
      board = Tresenraya.new
      board.send(side)[2][2] = true
      SpeakCapture.clear
      frame(board, Input::C)
      assert_equal [], SpeakCapture.lines, "a cell held in #{side}"
    end
  end

  test "when the rival opens the game its first move is said on the first frame, queued" do
    board = Tresenraya.new(1)
    frame(board)
    assert_equal [[t(:rmg_ttt_enemy_move, :row => 2, :col => 2), false]], SpeakCapture.log
  end

  test "the accept key places no cross while it is the rival's turn" do
    board = Tresenraya.new(1)
    frame(board, Input::C)
    assert_equal false, board.playpos[2][2]
  end

  test "back raises the tic-tac-toe's own close flag" do
    board = Tresenraya.new
    frame(board, Input::B)
    assert_equal 1, board.cerrar
  end

  test "the minior cursor starts on the bottom-left and each arrow says the colour, its group's size and the cell" do
    board = Miniorgame.new(BOARD)
    [Input::UP, Input::RIGHT, Input::DOWN].each { |k| frame(board, k) }
    assert_equal [[mg_cell(:rmg_amarillo, 1, 9, 1), true], [mg_cell(:rmg_verde, 86, 9, 2), true],
                  [mg_cell(:rmg_rojo, 3, 10, 2), true]], SpeakCapture.log
  end

  test "the minior cursor stops at each edge of the board without a word" do
    { [Input::LEFT] => 0, [Input::DOWN] => 0, [Input::UP] * 10 => 9, [Input::RIGHT] * 9 => 8 }.each do |keys, said|
      board = Miniorgame.new(BOARD)
      SpeakCapture.clear
      keys.each { |k| frame(board, k) }
      assert_equal said, SpeakCapture.lines.length, "pressing #{keys.inspect}"
    end
  end

  test "each minior colour is named with the mod's word, and one it has no word for as the game names it" do
    { "r" => t(:rmg_rojo), "a" => t(:rmg_amarillo), "v" => t(:rmg_verde), "z" => t(:rmg_azul), "l" => t(:rmg_lila),
      "n" => "miniornegro" }.each do |ch, word|
      board = Miniorgame.new(["ggggggggg"] * 9 + ["g#{ch}ggggggg"])
      SpeakCapture.clear
      frame(board, Input::RIGHT)
      assert_equal [t(:rmg_mg_cell, :color => word, :n => 1, :row => 10, :col => 2)], SpeakCapture.lines, "for #{ch}"
    end
  end

  test "an empty cell of the minior board is said as empty" do
    board = Miniorgame.new(BOARD)
    board.miniorsmatrix[9][1] = nil
    frame(board, Input::RIGHT)
    assert_equal [[t(:rmg_mg_empty, :row => 10, :col => 2), true]], SpeakCapture.log
  end

  test "the accept key bursts the focused group of miniors through the game's own calls" do
    board = Miniorgame.new(BOARD)
    frame(board, Input::C)
    board.deleteselected
    assert_equal [nil, nil, nil, "miniorverde"], board.miniorsmatrix[9][0, 4].map { |m| m && m.color }
  end

  test "a burst's score is said once the game's loop has counted it, queued" do
    board = Miniorgame.new(BOARD)
    frame(board, Input::C)
    board.deleteselected
    frame(board)
    assert_equal [[t(:rmg_mg_score, :pts => 2800, :left => 87), false]], SpeakCapture.log
  end

  test "every later burst's score is said too" do
    board = Miniorgame.new(PAIRS)
    burst(board)
    SpeakCapture.clear
    burst(board, Input::RIGHT, Input::RIGHT, Input::RIGHT)
    assert_equal [t(:rmg_mg_score, :pts => 2400, :left => 86), false], SpeakCapture.log.last
  end

  test "the accept key on a lone minior or an empty cell says it has no group and bursts nothing" do
    { "a lone minior" => [Input::UP], "an empty cell" => [] }.each do |what, walk|
      board = Miniorgame.new(BOARD)
      board.miniorsmatrix[9][0] = nil if walk.empty?
      walk.each { |k| frame(board, k) }
      SpeakCapture.clear
      frame(board, Input::C)
      board.deleteselected
      assert_equal [[t(:rmg_mg_no_group), true]], SpeakCapture.log, what
      assert_equal 0, board.total, "nothing taken away on #{what}"
    end
  end

  test "back closes the minior board and A starts it again, the game's own keys" do
    { Input::B => [1, 0], Input::A => [0, 1] }.each do |key, flags|
      board = Miniorgame.new(BOARD)
      frame(board, key)
      assert_equal flags, [board.cerrar, board.reset], "for key #{key}"
    end
  end

  test "a round says its goal and both counters as the game paints them when it starts, queued, and once" do
    Miniorgame.new(BOARD).diff(0)
    assert_equal [["¡Puedes dejarte hasta 5 Minior! Pts: 0. Restantes: 90", false]], SpeakCapture.log
  end

  test "each difficulty's round says the goal the game paints for it" do
    { 1 => 15, 2 => 10 }.each do |level, most|
      SpeakCapture.clear
      Miniorgame.new(BOARD).diff(level)
      assert_equal ["¡Puedes dejarte hasta #{most} Minior! Pts: 0. Restantes: 90"], SpeakCapture.lines, "level #{level}"
    end
  end

  test "the round the game starts anew after A or a game over says its goal again" do
    2.times { Miniorgame.new(BOARD).diff(1) }
    assert_equal ["¡Puedes dejarte hasta 15 Minior! Pts: 0. Restantes: 90"] * 2, SpeakCapture.lines
  end

  test "the focused difficulty is said on the opening frame and not again while it stands" do
    menu = Menuminior.new
    frame(menu)
    frame(menu)
    assert_equal [[t(:rmg_mm_easy), true]], SpeakCapture.log
  end

  test "up and down say each difficulty the game moves to, wrapping as it does" do
    menu = Menuminior.new
    frame(menu)
    SpeakCapture.clear
    [Input::DOWN, Input::DOWN, Input::DOWN, Input::UP].each { |k| frame(menu, k) }
    assert_equal [t(:rmg_mm_normal), t(:rmg_mm_hard), t(:rmg_mm_easy), t(:rmg_mm_hard)], SpeakCapture.lines
  end

  test "the help the game paints over the menu is said once, as painted" do
    menu = Menuminior.new
    frame(menu)
    SpeakCapture.clear
    frame(menu, Input::A)
    frame(menu)
    assert_equal [[Menuminior::HELP, true]], SpeakCapture.log
  end

  test "the help is said again when it opens again after back took it away" do
    menu = Menuminior.new
    frame(menu)
    frame(menu, Input::A)
    frame(menu, Input::B)
    SpeakCapture.clear
    frame(menu, Input::A)
    assert_equal [Menuminior::HELP], SpeakCapture.lines
  end

  test "walking the Unown names each one's letter, value and side, wrapping past either end" do
    { [Input::RIGHT] => un_piece("M", 1000, :rmg_un_left), [Input::RIGHT] * 3 => un_piece("D", 500, :rmg_un_left),
      [Input::DOWN] * 7 => un_piece("C", 100, :rmg_un_left), [Input::DOWN] * 11 => un_piece("L", 50, :rmg_un_left),
      [Input::LEFT] => un_piece("I", 1, :rmg_un_left), [Input::UP] * 4 => un_piece("V", 5, :rmg_un_left),
      [Input::UP] * 5 => un_piece("X", 10, :rmg_un_right) }.each do |keys, line|
      balance = Unowngame.new
      SpeakCapture.clear
      keys.each { |k| frame(balance, k) }
      assert_equal [line, true], SpeakCapture.log.last, "after #{keys.inspect}"
    end
  end

  test "the accept key carries the focused Unown across the split and says both totals" do
    balance = Unowngame.new
    frame(balance, Input::C)
    assert_equal [[t(:rmg_un_moved, :letter => "M", :right => 1010, :left => 4512), true]], SpeakCapture.log
    assert_equal [345, [1010, 4512]], [balance.sprites["M0"].x, balance.totals], "120 past the split, the game's totals"
  end

  test "an Unown on the right is carried back to the left" do
    balance = Unowngame.new
    5.times { frame(balance, Input::LEFT) }
    SpeakCapture.clear
    frame(balance, Input::C)
    assert_equal [[t(:rmg_un_moved, :letter => "X", :right => 0, :left => 5522), true]], SpeakCapture.log
    assert_equal 105, balance.sprites["X"].x, "120 short of the split"
  end

  test "the Unown is let go within the frame, so the game's loop does not drag it after the mouse" do
    balance = Unowngame.new
    frame(balance, Input::C)
    balance.actu_pass
    assert_equal 345, balance.sprites["M0"].x
  end

  test "A says both sides' Unown totals" do
    balance = Unowngame.new
    frame(balance, Input::A)
    assert_equal [[t(:rmg_un_totals, :right => 10, :left => 5512), true]], SpeakCapture.log
  end

  test "an Unown the game has disposed of is passed over" do
    balance = Unowngame.new
    %w[M1 M2].each { |k| balance.sprites[k].dispose }
    frame(balance, Input::RIGHT)
    assert_equal [[un_piece("D", 500, :rmg_un_left), true]], SpeakCapture.log
  end

  test "with every Unown gone the keys say nothing" do
    balance = Unowngame.new
    balance.sprites.each_value { |sp| sp.dispose }
    [Input::RIGHT, Input::C, Input::A].each { |k| frame(balance, k) }
    assert_nothing_spoken
  end

  test "a round names the pearl to find, then the bags' layout before they are shuffled, queued" do
    shells = Perlita.new
    shells.pearls = %w[azul]
    shells.cerrarsaquitos
    assert_equal [[t(:rmg_pl_target, :color => t(:rmg_pl_azul)), true],
                  [t(:rmg_pl_layout, :l => t(:rmg_pl_azul), :c => t(:rmg_pl_amarilla), :r => t(:rmg_pl_roja)), false]],
                 SpeakCapture.log
  end

  test "the pearl and the layout are named in the player's language, an unknown pearl as the game names it" do
    PokeAccess::Config.language = :en
    layout = t(:rmg_pl_layout, :l => t(:rmg_pl_azul), :c => t(:rmg_pl_amarilla), :r => t(:rmg_pl_roja))
    { "amarilla" => t(:rmg_pl_amarilla), "dorada" => "dorada" }.each do |drawn, word|
      shells = Perlita.new
      shells.pearls = [drawn]
      SpeakCapture.clear
      shells.cerrarsaquitos
      assert_equal [t(:rmg_pl_target, :color => word), layout], SpeakCapture.lines, "for #{drawn}"
    end
  end

  test "a shuffle is said as the two positions that crossed, never as the bags" do
    { %w[sacorojo sacoazul] => [:rmg_pl_left, :rmg_pl_right],
      %w[sacorojo sacoamarillo] => [:rmg_pl_center, :rmg_pl_right],
      %w[sacoazul sacoamarillo] => [:rmg_pl_left, :rmg_pl_center] }.each do |pair, (a, b)|
      shells = Perlita.new
      shells.crossings = [pair]
      SpeakCapture.clear
      shells.moversaquitos
      assert_equal [[swap(a, b), false]], SpeakCapture.log, "crossing #{pair.inspect}"
    end
  end

  test "a later shuffle is said by the positions the bags stand on now" do
    shells = Perlita.new
    shells.crossings = [%w[sacorojo sacoazul], %w[sacoazul sacoamarillo]]
    shells.moversaquitos
    SpeakCapture.clear
    shells.moversaquitos
    assert_equal [[swap(:rmg_pl_center, :rmg_pl_right), false]], SpeakCapture.log
  end

  # The game's Ruby 1.8.7 keeps no order in a hash, so the bags before a shuffle can come in any order.
  test "a shuffle is said lowest position first, whatever order its bags are listed in" do
    shells = Perlita.new
    shells.sprites["sacoazul"].x = 360
    shells.sprites["sacorojo"].x = 60
    PokeAccess::ReaMouse.pl_swap(shells, "sacorojo" => 360, "sacoamarillo" => 210, "sacoazul" => 60)
    assert_equal [[swap(:rmg_pl_left, :rmg_pl_right), false]], SpeakCapture.log
  end

  test "a shuffle that leaves every bag in place says nothing" do
    PokeAccess::ReaMouse.pl_swap(Perlita.new, "sacoazul" => 60, "sacoamarillo" => 210, "sacorojo" => 360)
    assert_nothing_spoken
  end

  test "left and right walk the three positions from the centre, said by position, an edge said again" do
    shells = Perlita.new
    [Input::LEFT, Input::LEFT, Input::RIGHT, Input::RIGHT, Input::RIGHT].each { |k| frame(shells, k) }
    assert_equal [:rmg_pl_left, :rmg_pl_left, :rmg_pl_center, :rmg_pl_right, :rmg_pl_right].map { |k| [t(k), true] },
                 SpeakCapture.log
  end

  test "the accept key opens the bag that stands at the focused position after the shuffles" do
    shells = opened_shells
    frame(shells, Input::RIGHT)
    frame(shells, Input::C)
    assert_equal [1, 0], [shells.victorias, shells.derrotas], "the blue bag, shuffled to the right, was opened"
    assert_equal 1, SpeakCapture.lines.count(t(:rmg_ck_hit, :v => 1, :n => 1, :tot => 5)), "the hit is said"
  end

  test "the verdict counts every round the game has played" do
    shells = opened_shells
    frame(shells, Input::RIGHT)
    frame(shells, Input::C)
    SpeakCapture.clear
    frame(shells, Input::C)
    assert_equal [1, 1], [shells.victorias, shells.derrotas], "the yellow bag, now on the right, was opened"
    assert_equal 1, SpeakCapture.lines.count(t(:rmg_ck_miss, :v => 1, :n => 2, :tot => 5)), "the second round's miss"
  end

  test "the verdict does not cut off the next round's pearl, layout and shuffles that abrirsaquito started" do
    shells = opened_shells
    frame(shells, Input::RIGHT)
    SpeakCapture.clear
    frame(shells, Input::C)
    said = [t(:rmg_ck_hit, :v => 1, :n => 1, :tot => 5), t(:rmg_pl_target, :color => t(:rmg_pl_roja)),
            t(:rmg_pl_layout, :l => t(:rmg_pl_amarilla), :c => t(:rmg_pl_roja), :r => t(:rmg_pl_azul)),
            swap(:rmg_pl_left, :rmg_pl_center), swap(:rmg_pl_center, :rmg_pl_right), swap(:rmg_pl_left, :rmg_pl_center)]
    assert_equal said.sort, SpeakCapture.lines.sort, "the verdict and the next round"
    cutting = SpeakCapture.log.drop(1).select { |_text, interrupt| interrupt }
    assert_equal [], cutting, "nothing cuts off a line before it"
  end

  test "the fifth round's verdict ends the game and is said alone" do
    shells = Perlita.new
    shells.pearls = %w[roja]
    shells.cerrarsaquitos
    shells.victorias = 2
    shells.derrotas = 2
    SpeakCapture.clear
    frame(shells, Input::C)
    assert_equal [t(:rmg_ck_miss, :v => 2, :n => 5, :tot => 5)], SpeakCapture.lines
  end

  test "every frame shows the bubble with the pearl to find, as the game's input does" do
    shells = opened_shells
    frame(shells)
    assert_equal [true, true], [shells.sprites["bocadillo"].visible, shells.sprites["bolabocadillo"].visible]
  end

  test "the accept key never reaches the shell game's own input, which would count three wins" do
    shells = opened_shells
    frame(shells, Input::C)
    assert_equal [0, 1], [shells.victorias, shells.derrotas]
  end

  test "a game method that raises inside a frame leaves the minigame running and the reader silent" do
    { "the cocktail mix" => [opened_bar, :colorescopa], "the tic-tac-toe check" => [Tresenraya.new, :comprobar],
      "the minior burst" => [Miniorgame.new(BOARD), :buscarvecinos], "the Unown count" => [Unowngame.new, :puntuacion],
      "the shell count" => [Perlita.new, :abrirsaquito] }.each do |what, (game, meth)|
      game.define_singleton_method(meth) { |*_args| raise "broken" }
      SpeakCapture.clear
      frame(game, Input::C)
      assert_equal [], SpeakCapture.lines, what
    end
  end

  private

  # The text of an i18n key in the language the test runs in.
  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # One frame of a minigame's loop: its input with these keys pressed.
  def frame(game, *keys)
    press(*keys) { game.input }
  end

  # The block's value with Input.trigger? answering true for keys alone, the stub's put back after.
  def press(*keys)
    stub = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |key, *_rest| keys.include?(key) }
    yield
  ensure
    Input.define_singleton_method(:trigger?, stub)
  end

  # A bar on its first round (purple to make, green next), its opening frame played and the speech cleared.
  def opened_bar
    bar = Cockteles.new("morado", "verde")
    frame(bar)
    SpeakCapture.clear
    bar
  end

  # Pours the bottle reached by walking with keys.
  def pour(bar, *walk)
    walk.each { |k| frame(bar, k) }
    frame(bar, Input::C)
  end

  # A cell of the tic-tac-toe board as the cursor says it.
  def ttt_cell(row, col, state)
    t(:rmg_ttt_cell, :row => row, :col => col, :state => t(state))
  end

  # A minior's cell as the cursor says it.
  def mg_cell(color, n, row, col)
    t(:rmg_mg_cell, :color => t(color), :n => n, :row => row, :col => col)
  end

  # Walks with keys, bursts the focused group, lets the game's loop count it and plays the next frame.
  def burst(board, *walk)
    walk.each { |k| frame(board, k) }
    frame(board, Input::C)
    board.deleteselected
    frame(board)
  end

  # An Unown piece as the cursor says it.
  def un_piece(letter, value, side)
    t(:rmg_un_piece, :letter => letter, :value => value, :side => t(side))
  end

  # A shell game past its opening, as the game's constructor leaves it before its loop: the bags closed over the first
  # pearl drawn and shuffled twice, the draws of PEARL_DRAWS and CROSSING_DRAWS queued, the speech cleared.
  def opened_shells
    shells = Perlita.new
    shells.pearls = PEARL_DRAWS.dup
    shells.crossings = CROSSING_DRAWS.dup
    shells.cerrarsaquitos
    2.times { shells.moversaquitos }
    SpeakCapture.clear
    shells
  end

  # A shuffle as it is said, by the two positions that crossed.
  def swap(a, b)
    t(:rmg_pl_swap, :a => t(a), :b => t(b))
  end
end
