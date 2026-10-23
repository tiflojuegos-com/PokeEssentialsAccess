# The Slot Machine, Tile Puzzle and Duel readers (core/field/minigames.rb): a reel's symbol as it lands, the wager as
# coins go in and the payout's result; the tile puzzle's cursor square, its held piece, moves and win; a duelist's HP.

# The slot machine as the game runs it (SlotMachineScene): its counters and reels, the wager, the replay flag and
# whether the reels spin. pbPayout pays the prize into the credit and empties the wager, as the game's does;
# MinigamesTest binds to it the hooks core/field/minigames.rb declares on the class.
class SlotMachineScene
  attr_accessor :wager, :replay, :gameRunning
  def initialize(sprites, wager, prize)
    @sprites = sprites
    @wager = wager
    @prize = prize
    @replay = false
    @gameRunning = false
  end

  def pbMain; end
  def update; end

  def pbPayout
    @sprites["credit"].score += @prize
    @wager = 0
  end
end

class MinigamesTest < PokeAccessTest
  Minigames = PokeAccess::Minigames
  # A score counter of the slot machine (the game's SlotMachineScore): the payout and the credit.
  Counter = Struct.new(:score)
  # A duelist's window (the game's DuelWindow): its name and HP.
  DuelPanel = Struct.new(:name, :hp)
  # The hook declarations of core/field/minigames.rb on the slot machine's scene, each through the end of its block.
  SLOT_HOOKS = /^PokeAccess::Hooks\.\w+\("SlotMachineScene".*?(?:\}\n|^end\n)/m

  # A slot machine reel (the game's SlotMachineReel): the three symbols it shows, top to bottom, and whether it spins.
  class Reel
    attr_accessor :showing
    def initialize(showing, spinning = false); @showing = showing; @spinning = spinning; end
    def land(showing); @showing = showing; @spinning = false; end
  end

  # The tile puzzle's cursor (the game's TilePuzzleCursor): its square and the arrows it shows for the legal moves
  # (down, left, right, up).
  class TileCursor
    attr_accessor :position
    def initialize(position, arrows = []); @position = position; @arrows = arrows; end
  end

  # The tile puzzle (the game's TilePuzzleScene): tiles[pos] the piece on each square, past width x height the reserve,
  # angles[piece] its quarter turns, @heldtile the piece in hand (-1 for none); solved as the game checks it.
  class TileScene
    def initialize(tiles, opts = {})
      @boardwidth = opts.fetch(:width, 2)
      @boardheight = opts.fetch(:height, 2)
      @tiles = tiles
      @angles = opts.fetch(:angles, Array.new(tiles.length, 0))
      @heldtile = opts.fetch(:held, -1)
      @sprites = { "cursor" => TileCursor.new(opts.fetch(:at, 0), opts.fetch(:arrows, [])) }
    end

    def pbCheckWin
      (0...@boardwidth * @boardheight).all? { |i| @tiles[i] == i && @angles[i] == 0 }
    end
  end

  # Binds, once, the hooks core/field/minigames.rb declares on SlotMachineScene: the mod declared them as it loaded,
  # before the stand-in existed. The source comes through the harness, so a mutant of it is the one bound.
  def self.bind_hooks
    @bound ||= begin
      path = File.join(Harness::ROOT, "core", "field", "minigames.rb")
      src = Harness.source(path)
      src.scan(SLOT_HOOKS) { eval($&, TOPLEVEL_BINDING, path, src[0, $~.begin(0)].count("\n") + 1) }
      true
    end
  end
  private_class_method :bind_hooks

  # Binds the hooks; the screen the hooks last noted, which the stand-in's hooked methods change, is put back after
  # each test.
  def setup
    super
    self.class.send(:bind_hooks)
    @screen = PokeAccess::Hooks.screen
  end

  def teardown
    PokeAccess::Hooks.note_screen(@screen)
    super
  end

  test "a reel says the symbol it lands on in its middle row, queued" do
    reel = Reel.new([0, 0, 0], true)
    Minigames.slot_reel_update(reel)
    reel.land([0, 3, 5])
    Minigames.slot_reel_update(reel)
    assert_equal [[t(:mg_slot_pikachu), false]], SpeakCapture.log
  end

  test "a reel says nothing while it turns, nor on the frames after it landed" do
    reel = Reel.new([0, 5, 1], true)
    2.times { Minigames.slot_reel_update(reel) }
    assert_nothing_spoken "turning"
    reel.land([0, 3, 5])
    Minigames.slot_reel_update(reel)
    SpeakCapture.clear
    2.times { Minigames.slot_reel_update(reel) }
    assert_nothing_spoken "landed"
  end

  test "a reel first seen standing still says nothing" do
    Minigames.slot_reel_update(Reel.new([0, 3, 5]))
    assert_nothing_spoken
  end

  test "a reel that lands with no symbols to show says nothing" do
    reel = Reel.new(nil, true)
    Minigames.slot_reel_update(reel)
    reel.land(nil)
    Minigames.slot_reel_update(reel)
    assert_nothing_spoken
  end

  test "names each symbol of the reels, and one it does not know by its number" do
    { 0 => t(:mg_slot_cherry), 1 => t(:mg_slot_magnemite), 4 => t(:mg_slot_psyduck), 5 => t(:mg_slot_seven_red),
      6 => t(:mg_slot_seven_blue), 7 => t(:mg_slot_replay), 9 => "9" }.each do |symbol, said|
      assert_equal said, Minigames.slot_symbol(symbol), "symbol #{symbol}"
    end
  end

  test "says the wager as coins go in, interrupting" do
    scene = World.stub_scene(:@wager => 1)
    Minigames.slot_wager(scene)
    scene.instance_variable_set(:@wager, 3)
    Minigames.slot_wager(scene)
    assert_equal [[t(:mg_slot_wager, :n => 1), true], [t(:mg_slot_wager, :n => 3), true]], SpeakCapture.log
  end

  test "the same wager on the next frame says nothing" do
    scene = World.stub_scene(:@wager => 2)
    Minigames.slot_wager(scene)
    SpeakCapture.clear
    Minigames.slot_wager(scene)
    assert_nothing_spoken
  end

  test "the wager emptied between spins is not said, and the same wager next spin is said again" do
    scene = World.stub_scene(:@wager => 1)
    Minigames.slot_wager(scene)
    SpeakCapture.clear
    scene.instance_variable_set(:@wager, 0)
    Minigames.slot_wager(scene)
    assert_nothing_spoken "the empty wager"
    scene.instance_variable_set(:@wager, 1)
    Minigames.slot_wager(scene)
    assert_equal [t(:mg_slot_wager, :n => 1)], SpeakCapture.lines
  end

  test "the slot machine's frame says the wager the coins put in, the credit left and the key that spins" do
    SlotMachineScene.new(slot_sprites(50, false), 2, 0).update
    said = "#{t(:mg_slot_wager, :n => 2)}, #{t(:mg_slot_credit, :n => 50)}"
    assert_equal [[PokeAccess::Verbosity.with_hint(said, t(:mg_slot_spin_hint, :key => "C")), true]], SpeakCapture.log
  end

  test "a third coin, or the last of the credit, starts the reels by itself: no key to spin is said" do
    { 3 => 50, 1 => 0 }.each do |wager, credit|
      SpeakCapture.clear
      SlotMachineScene.new(slot_sprites(credit, false), wager, 0).update
      assert_equal ["#{t(:mg_slot_wager, :n => wager)}, #{t(:mg_slot_credit, :n => credit)}"], SpeakCapture.lines,
                   "#{wager} coins in, #{credit} left"
    end
  end

  test "the free spin's three coins nobody put in are not said" do
    scene = SlotMachineScene.new(slot_sprites(9, false), 0, 0)
    scene.update
    scene.replay = true
    scene.wager = 3
    scene.update
    assert_nothing_spoken
  end

  test "the slot machine says the credit and its keys as it opens, queued, and the info key gives the prize table" do
    SlotMachineScene.new(slot_sprites(120, false), 0, 0).pbMain
    keys = t(:mg_slot_keys, :wager => t(:key_arrow_down), :spin => "C", :quit => "X")
    assert_equal [["#{t(:mg_slot_credit, :n => 120)}. #{keys}", false]], SpeakCapture.log
    assert_equal "#{t(:mg_slot_credit, :n => 120)}. #{t(:mg_slot_paytable)}", PokeAccess::Info.info_text
  end

  test "the reels starting to spin say so once, queued, with the key that stops them" do
    scene = SlotMachineScene.new(slot_sprites(50, false), 0, 0)
    scene.update
    scene.gameRunning = true
    2.times { scene.update }
    scene.gameRunning = false
    scene.update
    hint = t(:mg_slot_stop_hint, :key => "C")
    assert_equal [[PokeAccess::Verbosity.with_hint(t(:mg_slot_spinning), hint), false]], SpeakCapture.log
  end

  test "a paying line says its prize, the centre too, and sevens light the big or the regular bonus sign" do
    { [5, 5, 5] => [300, :mg_slot_bonus_big], [5, 6, 5] => [90, :mg_slot_bonus_reg], [3, 3, 3] => [15, nil] }.each do |mid, (pay, sign)|
      SpeakCapture.clear
      scene = slot_scene(50 + pay, :reels => true)
      sprites = scene.instance_variable_get(:@sprites)
      3.times { |i| sprites["reel#{i + 1}"].showing = [1, mid[i], 2] }
      Minigames.slot_payout(scene, 50, 1)
      said = ["#{t(:mg_slot_row_mid, :syms => mid.map { |s| Minigames.slot_symbol(s) }.join(', '))}, #{t(:mg_slot_pays, :n => pay)}",
              t(:mg_slot_won, :n => pay), (sign ? t(sign) : nil), t(:mg_slot_credit, :n => 50 + pay)].compact
      assert_equal [said.join(". ")], SpeakCapture.lines, mid.inspect
    end
  end

  test "a paying spin says the coins the credit gained, then the credit, queued" do
    { 65 => t(:mg_slot_won, :n => 15), 51 => t(:mg_slot_won, :n => 1) }.each do |credit, won|
      SpeakCapture.clear
      Minigames.slot_payout(slot_scene(credit), 50)
      assert_equal [["#{won}. #{t(:mg_slot_credit, :n => credit)}", false]], SpeakCapture.log, "credit #{credit}"
    end
  end

  test "a losing spin says there was no prize, then the credit" do
    Minigames.slot_payout(slot_scene(50), 50)
    assert_equal ["#{t(:mg_slot_lost)}. #{t(:mg_slot_credit, :n => 50)}"], SpeakCapture.lines
  end

  test "three replay symbols say a free game, not a loss" do
    Minigames.slot_payout(slot_scene(50, :replay => true), 50)
    assert_equal ["#{t(:mg_slot_replay_win)}. #{t(:mg_slot_credit, :n => 50)}"], SpeakCapture.lines
  end

  test "a spin with no credit counter says the result alone" do
    Minigames.slot_payout(slot_scene(nil), 50)
    assert_equal [t(:mg_slot_lost)], SpeakCapture.lines
  end

  test "two coins say the top and bottom rows first, three the diagonals too, one neither" do
    { 1 => [], 2 => rows_said, 3 => rows_said + diagonals_said }.each do |wager, lines|
      SpeakCapture.clear
      Minigames.slot_payout(slot_scene(50, :reels => true), 50, wager)
      assert_equal [(lines + [t(:mg_slot_lost), t(:mg_slot_credit, :n => 50)]).join(". ")], SpeakCapture.lines,
                   "#{wager} coins"
    end
  end

  test "the rows follow the wager on the scene when none was sampled" do
    Minigames.slot_payout(slot_scene(50, :reels => true, :wager => 2), 50)
    assert_equal [(rows_said + [t(:mg_slot_lost), t(:mg_slot_credit, :n => 50)]).join(". ")], SpeakCapture.lines
  end

  test "a board missing a reel, or showing a symbol that cannot be read, says no rows" do
    spoilers = { "a reel missing" => lambda { |sprites| sprites.delete("reel3") },
                 "a symbol that is no number" => lambda { |sprites| sprites["reel2"].showing = [3, Object.new, 5] } }
    spoilers.each do |what, spoil|
      SpeakCapture.clear
      scene = slot_scene(50, :reels => true)
      spoil.call(scene.instance_variable_get(:@sprites))
      Minigames.slot_payout(scene, 50, 3)
      assert_equal ["#{t(:mg_slot_lost)}. #{t(:mg_slot_credit, :n => 50)}"], SpeakCapture.lines, what
    end
  end

  test "a payout reads the rows the coins played paid for and the credit gained, though the game empties the wager" do
    SlotMachineScene.new(slot_sprites(50, true), 3, 15).pbPayout
    said = rows_said + diagonals_said + [t(:mg_slot_won, :n => 15), t(:mg_slot_credit, :n => 65)]
    assert_equal [[said.join(". "), false]], SpeakCapture.log
  end

  test "a reader handed a number it cannot read says nothing and raises nothing" do
    odd = Object.new
    reel = Reel.new([0, 0, 0], true)
    Minigames.slot_reel_update(reel)
    reel.land([0, odd, 0])
    tiles = TileScene.new([2, 1, 0, 3], :at => odd)
    readers = { "the wager" => lambda { Minigames.slot_wager(World.stub_scene(:@wager => odd)) },
                "a reel's symbol" => lambda { Minigames.slot_reel_update(reel) },
                "the credit" => lambda { Minigames.slot_payout(slot_scene(odd), 50) },
                "the tile cursor's square" => lambda { Minigames.tile_puzzle(tiles) } }
    readers.each { |what, read| assert_nil read.call, what }
    assert_nothing_spoken
  end

  test "the tile puzzle says the cursor's square and the piece on it, interrupting" do
    Minigames.tile_puzzle(TileScene.new([2, 1, 0, 3]))
    assert_equal [["#{t(:mg_rowcol, :row => 1, :col => 1)}, #{t(:tp_tile, :n => 3)}", true]], SpeakCapture.log
  end

  test "a piece on its own square says it is in place" do
    Minigames.tile_puzzle(TileScene.new([2, 1, 0, 3], :at => 1))
    assert_equal ["#{t(:mg_rowcol, :row => 1, :col => 2)}, #{t(:tp_tile, :n => 2)}, #{t(:tp_placed)}"],
                 SpeakCapture.lines
  end

  test "a turned piece says how far it is turned, and is not in place" do
    Minigames.tile_puzzle(TileScene.new([0, 1, 3, 2], :angles => [3, 0, 0, 0]))
    assert_equal ["#{t(:mg_rowcol, :row => 1, :col => 1)}, #{t(:tp_tile, :n => 1)}, #{t(:tp_rotated, :deg => 270)}"],
                 SpeakCapture.lines
  end

  test "with the puzzle help on, a piece out of place says the square it goes on" do
    PokeAccess::Config.puzzle_assist = true
    Minigames.tile_puzzle(TileScene.new([1, 3, 0, 2], :at => 1))
    said = [t(:mg_rowcol, :row => 1, :col => 2), t(:tp_tile, :n => 4), t(:tp_home, :row => 2, :col => 2)]
    assert_equal [said.join(", ")], SpeakCapture.lines
  end

  test "an empty square says it is empty" do
    { -1 => "the game's empty mark", nil => "no piece at all" }.each do |piece, what|
      SpeakCapture.clear
      Minigames.tile_puzzle(TileScene.new([piece, 1, 0, 3], :at => 0))
      assert_equal ["#{t(:mg_rowcol, :row => 1, :col => 1)}, #{t(:tp_empty)}"], SpeakCapture.lines, what
    end
  end

  test "a square of the reserve says its side and its row and column there" do
    { 6 => [:tp_reserve_left, 2, 1, 4], 5 => [:tp_reserve_right, 1, 1, 1] }.each do |at, (side, row, col, piece)|
      SpeakCapture.clear
      Minigames.tile_puzzle(TileScene.new([-1, -1, -1, -1, 2, 0, 3, 1], :at => at))
      assert_equal ["#{t(side)}, #{t(:mg_rowcol, :row => row, :col => col)}, #{t(:tp_tile, :n => piece)}"],
                   SpeakCapture.lines, "square #{at}"
    end
  end

  test "on a four-wide board each reserve panel is two columns, the inner one next to the board" do
    tiles = Array.new(32, -1)
    { 17 => [:tp_reserve_left, 1, 2], 18 => [:tp_reserve_right, 1, 1], 31 => [:tp_reserve_right, 4, 2] }.each do |at, (side, row, col)|
      assert_equal "#{t(side)}, #{t(:mg_rowcol, :row => row, :col => col)}, #{t(:tp_empty)}",
                   Minigames.tp_cell(TileScene.new(tiles, :width => 4, :height => 4), at), "square #{at}"
    end
  end

  test "the piece in hand says how far it is turned, and each turn says the new one" do
    scene = TileScene.new([-1, 1, 2, 3], :held => 0, :angles => [2, 0, 0, 0])
    Minigames.tile_puzzle(scene)
    scene.instance_variable_get(:@angles)[0] = 1
    Minigames.tile_puzzle(scene)
    scene.instance_variable_get(:@angles)[0] = 0
    Minigames.tile_puzzle(scene)
    square = "#{t(:mg_rowcol, :row => 1, :col => 1)}, #{t(:tp_empty)}, #{t(:tp_holding, :n => 1)}"
    assert_equal ["#{square}, #{t(:tp_rotated, :deg => 180)}", "#{square}, #{t(:tp_rotated, :deg => 90)}", square],
                 SpeakCapture.lines
  end

  test "reads the square on a board of the game's own size" do
    Minigames.tile_puzzle(TileScene.new((0...9).to_a.reverse, :width => 3, :height => 3, :at => 5))
    assert_equal ["#{t(:mg_rowcol, :row => 2, :col => 3)}, #{t(:tp_tile, :n => 4)}"], SpeakCapture.lines
  end

  test "says the piece in hand and the moves the cursor's arrows allow" do
    cases = { 2 => [[true, false, true, false], "#{t(:dir_down)}, #{t(:dir_right)}"],
              0 => [[false, true, false, true], "#{t(:dir_left)}, #{t(:dir_up)}"] }
    cases.each do |held, (arrows, moves)|
      SpeakCapture.clear
      Minigames.tile_puzzle(TileScene.new([2, 1, 0, 3], :held => held, :arrows => arrows))
      assert_equal ["#{t(:mg_rowcol, :row => 1, :col => 1)}, #{t(:tp_tile, :n => 3)}, " \
                    "#{t(:tp_holding, :n => held + 1)}, #{t(:tp_moves, :dirs => moves)}"],
                   SpeakCapture.lines, "piece #{held + 1} in hand"
    end
  end

  test "with no piece in hand and no arrows lit, says neither" do
    cases = { "none lit" => [false, false, false, false], "none drawn yet" => [], "a cursor without arrows" => nil }
    cases.each do |what, arrows|
      SpeakCapture.clear
      Minigames.tile_puzzle(TileScene.new([2, 1, 0, 3], :held => -1, :arrows => arrows))
      assert_equal ["#{t(:mg_rowcol, :row => 1, :col => 1)}, #{t(:tp_tile, :n => 3)}"], SpeakCapture.lines, what
    end
  end

  test "a cursor held on the same square says nothing more" do
    scene = TileScene.new([2, 1, 0, 3], :at => 1)
    Minigames.tile_puzzle(scene)
    SpeakCapture.clear
    Minigames.tile_puzzle(scene)
    assert_nothing_spoken
  end

  test "a solved board says the win alone" do
    Minigames.tile_puzzle(TileScene.new([0, 1, 2, 3], :held => 1, :arrows => [true, true, true, true]))
    assert_equal [[t(:tp_solved), true]], SpeakCapture.log
  end

  test "a puzzle with no cursor says nothing" do
    scene = TileScene.new([2, 1, 0, 3])
    scene.instance_variable_get(:@sprites).delete("cursor")
    Minigames.tile_puzzle(scene)
    assert_nothing_spoken
  end

  test "a duelist's window says the HP as it changes, queued" do
    panel = DuelPanel.new("Rojo", 3)
    Minigames.duel_hp(panel)
    panel.hp = 2
    Minigames.duel_hp(panel)
    assert_equal [[t(:mg_duel_hp, :who => "Rojo", :hp => 3), false], [t(:mg_duel_hp, :who => "Rojo", :hp => 2), false]],
                 SpeakCapture.log
  end

  test "a duelist's window with the same HP, or none yet, says nothing" do
    panel = DuelPanel.new("Rojo", 3)
    Minigames.duel_hp(panel)
    SpeakCapture.clear
    Minigames.duel_hp(panel)
    Minigames.duel_hp(DuelPanel.new("Azul", nil))
    assert_nothing_spoken
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # The spoken names of the given symbol keys, as a row of reels says them.
  def names(*keys)
    keys.map { |k| t(k) }.join(", ")
  end

  # The top and bottom rows of slot_sprites' reels, as said.
  def rows_said
    [t(:mg_slot_row_top, :syms => names(:mg_slot_magnemite, :mg_slot_pikachu, :mg_slot_seven_blue)),
     t(:mg_slot_row_bottom, :syms => names(:mg_slot_pikachu, :mg_slot_seven_red, :mg_slot_cherry))]
  end

  # The two diagonals of slot_sprites' reels, falling then rising, as said.
  def diagonals_said
    [t(:mg_slot_diag1, :syms => names(:mg_slot_magnemite, :mg_slot_psyduck, :mg_slot_cherry)),
     t(:mg_slot_diag2, :syms => names(:mg_slot_pikachu, :mg_slot_psyduck, :mg_slot_seven_blue))]
  end

  # The slot machine's sprites after a spin: the payout counter drained, the credit counter (none for nil) and, with
  # reels, the three reels showing [Magnemite, Shellder, Pikachu], [Pikachu, Psyduck, red seven] and
  # [blue seven, replay, cherry], no line of which pays.
  def slot_sprites(credit, reels)
    sprites = { "payout" => Counter.new(0) }
    sprites["credit"] = Counter.new(credit) if credit
    if reels
      sprites["reel1"] = Reel.new([1, 2, 3])
      sprites["reel2"] = Reel.new([3, 4, 5])
      sprites["reel3"] = Reel.new([6, 7, 0])
    end
    sprites
  end

  # A slot machine scene after a spin, read through the module: slot_sprites with opts :reels, and the replay flag
  # and wager the scene keeps.
  def slot_scene(credit, opts = {})
    World.stub_scene(:@sprites => slot_sprites(credit, opts[:reels]), :@replay => opts.fetch(:replay, false),
                     :@wager => opts.fetch(:wager, 0))
  end
end
