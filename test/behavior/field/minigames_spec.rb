# Slot Machine and Tile Puzzle readers (core/field/minigames), driven through the module functions with stub scenes.

# A minimal stand-in for the game's sprite objects the readers introspect (payout counter, cursor).
class FakeSlotSprite
  attr_accessor :score
  def initialize(score); @score = score; end
end
class FakeCursorSprite
  attr_accessor :position
  def initialize(pos); @position = pos; end
end

# --- Slot Machine ---------------------------------------------------------------------------------------

# A slot reel says its centre symbol once, on the frame @spinning goes false (it turns on after stopSpinning).
Suite.define("minigames: slot reel voices the symbol it lands on, not the one it was asked to stop at") do
  reel = Object.new
  def reel.showing; @showing; end
  reel.instance_variable_set(:@showing, [0, 5, 1])
  reel.instance_variable_set(:@spinning, true)
  PokeAccess::Minigames.slot_reel_update(reel)
  silent "a reel still turning says nothing, however long it has been asked to stop"

  SpeakCapture.clear
  reel.instance_variable_set(:@showing, [0, 3, 5]) # top cherry, middle Pikachu, bottom red-seven
  reel.instance_variable_set(:@spinning, false)
  PokeAccess::Minigames.slot_reel_update(reel)
  spoke "the centre symbol is spoken on the frame the reel lands", /Pikachu/

  SpeakCapture.clear
  PokeAccess::Minigames.slot_reel_update(reel)
  silent "and not again on every frame it stays stopped"
end

Suite.define("minigames: slot wager is voiced once per change") do
  scene = Object.new
  scene.instance_variable_set(:@wager, 1)
  PokeAccess::Minigames.slot_wager(scene)
  spoke_once "inserting the first coin announces one coin wagered", /1/

  SpeakCapture.clear
  PokeAccess::Minigames.slot_wager(scene)
  silent "the same wager is not repeated every frame"

  SpeakCapture.clear
  scene.instance_variable_set(:@wager, 2)
  PokeAccess::Minigames.slot_wager(scene)
  spoke "raising the wager announces the new amount", /2/
end

# The slot payout is the credit gained across pbPayout (the payout counter reads 0 by then); the extra rows follow the
# wager the hook sampled before it, since pbPayout zeroes @wager.
Suite.define("minigames: slot payout voices a win, a loss and a free game") do
  won = Object.new
  won.instance_variable_set(:@sprites, { "payout" => FakeSlotSprite.new(0), "credit" => FakeSlotSprite.new(65) })
  won.instance_variable_set(:@replay, false)
  PokeAccess::Minigames.slot_payout(won, 50)
  spoke "a paying spin announces the coins the credit actually gained", /15/

  SpeakCapture.clear
  lost = Object.new
  lost.instance_variable_set(:@sprites, { "payout" => FakeSlotSprite.new(0), "credit" => FakeSlotSprite.new(50) })
  lost.instance_variable_set(:@replay, false)
  PokeAccess::Minigames.slot_payout(lost, 50)
  spoke "a losing spin says there was no win", /#{PokeAccess::I18n.t(:mg_slot_lost)}/

  SpeakCapture.clear
  free = Object.new
  free.instance_variable_set(:@sprites, { "payout" => FakeSlotSprite.new(0), "credit" => FakeSlotSprite.new(50) })
  free.instance_variable_set(:@replay, true)
  PokeAccess::Minigames.slot_payout(free, 50)
  spoke "three replay symbols announce a free game", /#{PokeAccess::I18n.t(:mg_slot_replay_win)}/

  SpeakCapture.clear
  reel = Class.new { attr_reader :showing; def initialize(s); @showing = s; end }
  rows = Object.new
  rows.instance_variable_set(:@sprites, { "payout" => FakeSlotSprite.new(0), "credit" => FakeSlotSprite.new(50),
                                          "reel1" => reel.new([0, 1, 2]), "reel2" => reel.new([0, 1, 2]),
                                          "reel3" => reel.new([0, 1, 2]) })
  rows.instance_variable_set(:@replay, false)
  rows.instance_variable_set(:@wager, 0)
  PokeAccess::Minigames.slot_payout(rows, 50, 3)
  spoke "three coins voice the top row from the wager sampled before the payout",
        /#{Regexp.escape(PokeAccess::I18n.t(:mg_slot_row_top, :syms => "").strip)}/
  spoke "and the first diagonal", /#{Regexp.escape(PokeAccess::I18n.t(:mg_slot_diag1, :syms => "").strip)}/
end

# --- Tile Puzzle ----------------------------------------------------------------------------------------

# A 2x2 board. tiles[pos] = tile id at that position; solved when tile id == pos and angle 0.
def tp_scene(cursor_pos, tiles, angles = [0, 0, 0, 0])
  s = Object.new
  s.instance_variable_set(:@boardwidth, 2)
  s.instance_variable_set(:@boardheight, 2)
  s.instance_variable_set(:@tiles, tiles)
  s.instance_variable_set(:@angles, angles)
  s.instance_variable_set(:@sprites, { "cursor" => FakeCursorSprite.new(cursor_pos) })
  def s.pbCheckWin
    t = instance_variable_get(:@tiles); a = instance_variable_get(:@angles)
    (0...t.length).all? { |i| t[i] == i && (a[i].to_i % 4) == 0 }
  end
  s
end

Suite.define("minigames: tile puzzle voices the cursor cell with position and tile") do
  scene = tp_scene(0, [2, 1, 0, 3])
  PokeAccess::Minigames.tile_puzzle(scene)
  spoke "the cursor cell reads its row/column", /#{PokeAccess::I18n.t(:mg_rowcol, :row => 1, :col => 1)}/
  spoke "the cursor cell reads which tile sits there", /#{PokeAccess::I18n.t(:tp_tile, :n => 3)}/
end

Suite.define("minigames: tile puzzle marks a tile already in place and dedups a held cursor") do
  scene = tp_scene(1, [2, 1, 0, 3])
  PokeAccess::Minigames.tile_puzzle(scene)
  spoke "a tile in its solved spot is announced as placed", /#{PokeAccess::I18n.t(:tp_placed)}/

  SpeakCapture.clear
  PokeAccess::Minigames.tile_puzzle(scene)
  silent "holding the cursor on the same cell does not repeat"
end

Suite.define("minigames: tile puzzle announces the win when solved") do
  scene = tp_scene(0, [0, 1, 2, 3])
  PokeAccess::Minigames.tile_puzzle(scene)
  spoke "a solved board announces the win", /#{PokeAccess::I18n.t(:tp_solved)}/
end
