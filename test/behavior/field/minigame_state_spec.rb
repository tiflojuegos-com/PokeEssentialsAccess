# The state of a minigame in progress, which both boards repaint constantly and neither said.
#
# Voltorb Flip: the coins won so far are the whole decision of the game. Flipping a 2 or a 3 multiplies the
# round's takings and every flip sounds alike, so with the total unspoken a player has nothing to weigh
# "one more card" against, and cannot tell a board they are winning from one already lost.
#
# Triple Triad: the scoreboard. A turn in which the opponent flips three cards changes who is winning
# without a word, and the only other way to know is to walk all nine cells.
#
# Both ship in all fourteen surveyed games, so both are core.
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

  # A Voltorb (or a cleared board) makes the game build a NEW board from inside its input loop, cursor back
  # on the first cell and takings at zero. Read against the old memo it was a step onto a cell already
  # described, so neither the level nor the row and column counts of the new board were said.
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
  eq "a flip in the opponent's turn is announced", SpeakCapture.lines,
     [PokeAccess::I18n.t(:triad_score, :you => 3, :foe => 0)]

  SpeakCapture.clear
  tt.score(Object.new)
  silent "a scene with no board at all is not an error"

  # Under the "countunplayed" rule the scoreboard adds the cards each side still holds, so the board alone
  # is NOT the score (Essentials 017_Minigames/002_Minigame_TripleTriad.rb:576-579). Counting only the cells
  # there announced a number the screen was not showing.
  def battle.countUnplayedCards; true; end
  scene.instance_variable_set(:@cardIndexes, [1, 2])
  scene.instance_variable_set(:@opponentCardIndexes, [7])
  SpeakCapture.clear
  tt.score(scene)
  eq "the hands count too, exactly as the scoreboard counts them", SpeakCapture.lines,
     [PokeAccess::I18n.t(:triad_score, :you => 5, :foe => 1)]
end

# Triple Triad writes its help window TWO ways: through pbDisplay, which the mod hooks, and by assigning
# straight to the sprite -- eight of those across four methods, none of them hooked. Among them the line
# that says the confirm key opens the rival's hand: a feature the mod can read and the player had no way of
# knowing was there.
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

    # The window keeps its prompt for the whole loop, and the poll runs every frame: the message path's own
    # half-second window let the same line back in twice a second for as long as the player took to choose.
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

# The DECK selector, where the player picks which cards to duel with. Its list is a plain command window, so
# the generic reader already says "Bulbasaur x3" -- but the four side numbers, which are the ONLY thing that
# decides which card to take, are a picture. They were said later, in hand, when the choice is already made.
#
# The window class is the one half the game's menus use, so the extractor has to be transparent everywhere
# else. It especially must not return nil: focused_text does not fall back to the generic on nil, only on an
# exception, so a nil here would silence every command window in the game.
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
    match "and the four sides follow", line,
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

# The mining wall. The game ends at 49 hits in all six games that ship the screen, and the only thing that
# says how close that is is a bar of cracks drawn across the top: a blind player dug until the roof fell in,
# losing whatever was still buried.
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

  # The hammer costs two hits a blow: thirty-one hits of wall are sixteen hammer blows, not thirty-one.
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
