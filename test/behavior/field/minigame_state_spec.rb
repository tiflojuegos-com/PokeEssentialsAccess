# Minigame state. Voltorb Flip says its level on arrival and the coins when they change; a new board (cursor back on
# the first cell, takings at zero) says its level and first row and column counts again.
Suite.define("minigames: Voltorb Flip says the level on arrival and the coins whenever they move") do
  scene = Object.new
  scene.instance_variable_set(:@index, [0, 0])
  scene.instance_variable_set(:@squares, Array.new(25) { 0 })
  scene.instance_variable_set(:@marks, Array.new(25) { 0 })
  scene.instance_variable_set(:@cursor, [[0, 0, 0, 0]])
  scene.instance_variable_set(:@points, 0)
  scene.instance_variable_set(:@level, 4)
  mg = PokeAccess::Minigames

  SpeakCapture.clear
  mg.voltorb_flip(scene)
  truthy "the board says how dangerous it is, once, on arrival",
         SpeakCapture.lines.first.include?(PokeAccess::I18n.t(:mg_level, :n => 4))

  SpeakCapture.clear
  scene.instance_variable_set(:@index, [1, 0])
  mg.voltorb_flip(scene)
  falsy "and does not repeat the level on every move",
        SpeakCapture.lines.first.include?(PokeAccess::I18n.t(:mg_level, :n => 4))

  SpeakCapture.clear
  scene.instance_variable_set(:@points, 24)
  mg.voltorb_flip(scene)
  truthy "a flip that changed the takings says the new total",
         SpeakCapture.lines.first.include?(PokeAccess::I18n.t(:mg_coins, :n => 24))

  SpeakCapture.clear
  scene.instance_variable_set(:@index, [2, 0])
  mg.voltorb_flip(scene)
  falsy "and moving with the takings unchanged does not say them again",
        SpeakCapture.lines.first.include?(PokeAccess::I18n.t(:mg_coins, :n => 24))

  SpeakCapture.clear
  scene.instance_variable_set(:@squares, Array.new(25) { 0 })
  scene.instance_variable_set(:@index, [0, 0])
  scene.instance_variable_set(:@points, 0)
  mg.voltorb_flip(scene)
  line = SpeakCapture.lines.join(" ")
  truthy "a new board says its level again", line.include?(PokeAccess::I18n.t(:mg_level, :n => 4))
  truthy "and the counts of its first row", line.include?(PokeAccess::I18n.t(:mg_row))
  truthy "and of its first column", line.include?(PokeAccess::I18n.t(:mg_col))
end

# Triple Triad says the score when it changes, counted off the board, plus the cards each side still holds under the
# "countunplayed" rule, as the scoreboard counts them.
Suite.define("minigames: Triple Triad says the score when it moves, counted off the board itself") do
  cell = Class.new do
    attr_accessor :owner
    def initialize(o); @owner = o; end
  end
  battle = Object.new
  board = [cell.new(1), cell.new(2), cell.new(0), cell.new(1), cell.new(0),
           cell.new(0), cell.new(0), cell.new(0), cell.new(0)]
  battle.instance_variable_set(:@board, board)
  def battle.width; 3; end
  def battle.height; 3; end
  def battle.board; @board; end
  scene = Object.new
  scene.instance_variable_set(:@battle, battle)
  tt = PokeAccess::TripleTriad

  SpeakCapture.clear
  tt.score(scene)
  eq "two cells yours against one theirs", SpeakCapture.lines,
     [PokeAccess::I18n.t(:triad_score, :you => 2, :foe => 1)]

  SpeakCapture.clear
  tt.score(scene)
  silent "a repaint that changed nothing says nothing"

  board[1].owner = 1
  SpeakCapture.clear
  tt.score(scene)
  eq "a flip is announced, the square that turned before the score it made", SpeakCapture.lines,
     ["#{PokeAccess::I18n.t(:triad_captures, :list => PokeAccess::I18n.t(:triad_cell, :row => 1, :col => 2))}. " \
      "#{PokeAccess::I18n.t(:triad_score, :you => 3, :foe => 0)}"]

  SpeakCapture.clear
  tt.score(Object.new)
  silent "a scene with no board at all is not an error"

  def battle.countUnplayedCards; true; end
  scene.instance_variable_set(:@cardIndexes, [1, 2])
  scene.instance_variable_set(:@opponentCardIndexes, [7])
  SpeakCapture.clear
  tt.score(scene)
  eq "the hands count too, exactly as the scoreboard counts them", SpeakCapture.lines,
     [PokeAccess::I18n.t(:triad_score, :you => 5, :foe => 1)]
end

# Triple Triad's poll reads each prompt the game assigns straight to its help window (bypassing pbDisplay) once while
# it stays up, past the half-second message dedup, and only while its loop runs.
Suite.define("minigames: Triple Triad reads the prompts it writes straight into its help window") do
  tt = PokeAccess::TripleTriad
  scene = Object.new
  win = Object.new
  def win.text; @t; end
  def win.text=(v); @t = v; end
  scene.instance_variable_set(:@sprites, { "helpwindow" => win })
  def scene.sprites; @sprites; end

  begin
    tt.start_deck(scene, [])
    win.text = "Elige 5 cartas para este duelo."
    SpeakCapture.clear
    tt.poll
    eq "the prompt the deck selector assigns is read", SpeakCapture.lines,
       ["Elige 5 cartas para este duelo."]

    SpeakCapture.clear
    tt.poll
    silent "and a frame where it had not changed says nothing"

    win.text = "Elige una carta, o mira al rival con Z."
    SpeakCapture.clear
    tt.poll
    eq "the line that says the rival's hand can be opened is read too", SpeakCapture.lines,
       ["Elige una carta, o mira al rival con Z."]

    PokeAccess.instance_variable_set(:@last_say_t, nil)
    SpeakCapture.clear
    tt.poll
    silent "and half a second later the prompt still on screen is not read again"

    win.text = ""
    SpeakCapture.clear
    tt.poll
    silent "clearing the window is not a line"
  ensure
    tt.stop
  end

  SpeakCapture.clear
  tt.poll
  silent "and with no loop running the window is nobody's business"
end

# The deck selector's rows add the card's type and four sides; elsewhere deck_row answers as the generic reader does
# (a stray nil would silence every command window: focused_text falls back only on an exception).
Suite.define("minigames: the Triple Triad deck list adds the four sides, and is transparent elsewhere") do
  tt = PokeAccess::TripleTriad
  win = Class.new do
    attr_accessor :index
    def initialize(cmds); @commands = cmds; @index = 0; end
  end
  w = win.new(["Bulbasaur x3", "Charmander x1"])

  before = PokeAccess::Menus.generic_focus(w, 0)
  eq "outside the deck loop it is exactly the generic reader", tt.deck_row(w, 0), before

  begin
    tt.start_deck(Object.new, [[1, 3], [4, 1]])
    line = tt.deck_row(w, 0)
    match "inside it, the row still says the species and how many are left", line, /Bulbasaur x3/
    match "the card's type follows", line, /#{Regexp.escape(PokeAccess::I18n.t(:mv_type, :t => PBTypes.getName(1)))}/
    match "and the four sides", line,
          /#{PokeAccess::I18n.t(:triad_sides, :n => 1, :e => 1, :s => 1, :w => 1).gsub(/\d+/, '\\d+')}/
    w.index = 1
    truthy "the next row reads its own card", tt.deck_row(w, 1) != line
    truthy "and its sides are the other card's",
           tt.deck_row(w, 1) =~ /Charmander/
    truthy "a row past the list answers what the generic reader answers there, which is nothing",
           tt.deck_row(w, 9) == PokeAccess::Menus.generic_focus(w, 9)
  ensure
    tt.stop
  end

  eq "and once the loop is over it is the generic reader again", tt.deck_row(w, 0), before
end

# The mining wall says the blows left (the game ends at 49 hits) once per block of cracks the bar draws, in hammer
# blows (two hits each) with the hammer in hand.
Suite.define("minigames: the mining wall says how much is left, at the rate the bar is drawn") do
  mg = PokeAccess::Minigames
  crack = Object.new
  def crack.hits; @h.to_i; end
  def crack.hits=(v); @h = v; end
  scene = Object.new
  scene.instance_variable_set(:@sprites, { "crack" => crack })
  def scene.sprites; @sprites; end

  crack.hits = 0
  SpeakCapture.clear
  mg.mining_wall(scene)
  silent "an untouched wall says nothing"

  crack.hits = 6
  SpeakCapture.clear
  mg.mining_wall(scene)
  eq "the first block of cracks says how many blows are left",
     SpeakCapture.lines, [PokeAccess::I18n.t(:mg_wall_left, :n => 43)]

  crack.hits = 9
  SpeakCapture.clear
  mg.mining_wall(scene)
  silent "and blows inside the same block say nothing, or it would talk on every swing"

  crack.hits = 12
  SpeakCapture.clear
  mg.mining_wall(scene)
  eq "the next block does", SpeakCapture.lines, [PokeAccess::I18n.t(:mg_wall_left, :n => 37)]

  cursor = Object.new
  cursor.instance_variable_set(:@mode, 1)
  scene.instance_variable_get(:@sprites)["cursor"] = cursor
  crack.hits = 18
  SpeakCapture.clear
  mg.mining_wall(scene)
  eq "with the hammer in hand the count is in hammer blows", SpeakCapture.lines,
     [PokeAccess::I18n.t(:mg_wall_left, :n => 16)]
  cursor.instance_variable_set(:@mode, 0)

  crack.hits = 49
  SpeakCapture.clear
  mg.mining_wall(scene)
  silent "and once the wall is gone there is nothing left to count"
end

# A mining wall square: layer is how much rock is left on it.
class MineTileStub
  attr_accessor :layer
  def initialize(layer); @layer = layer; end
end

Suite.define("minigames: each mining square says what it shows, and a blow says what it uncovered") do
  mg = PokeAccess::Minigames
  t = PokeAccess::I18n
  scene = Object.new
  tiles = {}
  (0...130).each { |i| tiles["tile#{i}"] = MineTileStub.new(3) }
  cursor = Object.new
  cursor.instance_variable_set(:@position, 0)
  cursor.instance_variable_set(:@mode, 0)
  def cursor.position; @position; end
  tiles["cursor"] = cursor
  scene.instance_variable_set(:@sprites, tiles)
  def scene.pbIsItemThere?(pos); [1, 2].include?(pos); end
  def scene.pbIsIronThere?(pos); pos == 14; end
  begin
    mg.mine_scene = scene
    mg.mining_cursor(cursor)
    eq "the first square: where it is, its rock, the tool", SpeakCapture.lines,
       [[t.t(:mg_rowcol, :row => 1, :col => 1), t.t(:mg_rock, :n => 3), t.t(:mg_pick)].join(", ")]

    tiles["tile1"].layer = 0
    SpeakCapture.clear
    cursor.instance_variable_set(:@position, 1)
    mg.mining_cursor(cursor)
    eq "a dug square over an item says so", SpeakCapture.lines,
       [[t.t(:mg_rowcol, :row => 1, :col => 2), t.t(:mg_tile_item)].join(", ")]

    tiles["tile14"].layer = 0
    SpeakCapture.clear
    cursor.instance_variable_set(:@position, 14)
    mg.mining_cursor(cursor)
    match "one over iron says iron", SpeakCapture.lines.join(" "), /#{t.t(:mg_tile_iron)}\z/

    tiles["tile14"].layer = 0
    tiles["tile2"].layer = 0
    SpeakCapture.clear
    mg.mining_after_hit(scene, false)
    eq "a blow that uncovers a new piece says so, then the square under the cursor", SpeakCapture.lines,
       [[t.t(:mg_item_peek), t.t(:mg_tile_iron)].join(", ")]
    SpeakCapture.clear
    mg.mining_after_hit(scene, false)
    eq "a blow that uncovers nothing new only reports the square", SpeakCapture.lines, [t.t(:mg_tile_iron)]
  ensure
    mg.mine_scene = nil
  end
end
