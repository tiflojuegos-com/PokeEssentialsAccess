# The info key's whole minigame board (core/field/minigames.rb): Voltorb Flip's rows and columns, the Tile Puzzle square
# by square with its reserve and pieces out of place; and the Tile Puzzle cursor's square, with the help where it goes.
class MinigameBoardsTest < PokeAccessTest
  # A Tile Puzzle cursor sprite: the square it is on.
  Cursor = Struct.new(:position)

  test "the info key reads the Voltorb Flip level and coins won, then every row's cards with its counts, then every column's" do
    PokeAccess::Minigames.voltorb_flip(voltorb_flip)
    h = t(:mg_hidden)
    rows = [[h, h, h, t(:mg_voltorb), h], [h, h, "3", h, h], [h, h, h, h, t(:mg_marked)], [h] * 5, [h] * 5]
    row_sums = [[3, 2], [7, 0], [6, 0], [5, 0], [5, 0]]
    col_sums = [[4, 1], [5, 0], [7, 0], [4, 1], [6, 0]]
    want = rows.each_with_index.map do |cells, r|
      t(:mg_board_row, :n => r + 1, :cells => cells.join(", "), :sum => row_sums[r][0], :voltorbs => row_sums[r][1])
    end
    want += col_sums.each_with_index.map do |(sum, voltorbs), c|
      t(:mg_board_col, :n => c + 1, :sum => sum, :voltorbs => voltorbs)
    end
    head = "#{t(:mg_level, :n => 1)}, #{t(:mg_vf_earned, :n => 3)}"
    assert_equal "#{head}. #{want.join('. ')}", PokeAccess::Info.info_text,
                 "a Voltorb face down and one turned up, a 3 turned up, a card marked, the rest hidden"
  end

  test "the info key reads the Tile Puzzle row by row, the pieces home said to be, and how many are out of place" do
    PokeAccess::Minigames.tile_puzzle(tile_puzzle([3, 1, 0, 2]))
    assert_equal [t(:tp_board_row, :n => 1, :cells => "#{t(:tp_tile, :n => 4)}, #{t(:tp_tile, :n => 2)} #{t(:tp_placed)}"),
                  t(:tp_board_row, :n => 2, :cells => "#{t(:tp_tile, :n => 1)}, #{t(:tp_tile, :n => 3)}"),
                  t(:tp_wrong, :n => 3)].join(". "),
                 PokeAccess::Info.info_text
  end

  test "a piece on its own square but turned is not home yet, and says how far it is turned" do
    PokeAccess::Minigames.tile_puzzle(tile_puzzle([0, 1, 2, 3], [0, 1, 0, 0]))
    home = t(:tp_placed)
    turned = "#{t(:tp_tile, :n => 2)} #{t(:tp_rotated, :deg => 90)}"
    assert_equal [t(:tp_board_row, :n => 1, :cells => "#{t(:tp_tile, :n => 1)} #{home}, #{turned}"),
                  t(:tp_board_row, :n => 2, :cells => "#{t(:tp_tile, :n => 3)} #{home}, #{t(:tp_tile, :n => 4)} #{home}"),
                  t(:tp_wrong, :n => 1)].join(". "),
                 PokeAccess::Info.info_text
  end

  test "the reserve says its rows that hold pieces by side, the pieces out of place, and an empty row holds none" do
    PokeAccess::Minigames.tile_puzzle(tile_puzzle([-1, 1, 2, 3, 0, -1, -1, -1]))
    home = t(:tp_placed)
    assert_equal [t(:tp_board_row, :n => 1, :cells => "#{t(:tp_empty)}, #{t(:tp_tile, :n => 2)} #{home}"),
                  t(:tp_board_row, :n => 2, :cells => "#{t(:tp_tile, :n => 3)} #{home}, #{t(:tp_tile, :n => 4)} #{home}"),
                  "#{t(:tp_reserve_left)}, #{t(:tp_board_row, :n => 1, :cells => t(:tp_tile, :n => 1))}",
                  t(:tp_wrong, :n => 1)].join(". "),
                 PokeAccess::Info.info_text
  end

  test "the info key names the piece in hand with its turn and counts it out of place" do
    scene = tile_puzzle([0, 1, 2, -1], [0, 0, 0, 3])
    scene.instance_variable_set(:@heldtile, 3)
    PokeAccess::Minigames.tile_puzzle(scene)
    home = t(:tp_placed)
    assert_equal [t(:tp_board_row, :n => 1, :cells => "#{t(:tp_tile, :n => 1)} #{home}, #{t(:tp_tile, :n => 2)} #{home}"),
                  t(:tp_board_row, :n => 2, :cells => "#{t(:tp_tile, :n => 3)} #{home}, #{t(:tp_empty)}"),
                  "#{t(:tp_holding, :n => 4)}, #{t(:tp_rotated, :deg => 270)}",
                  t(:tp_wrong, :n => 1)].join(". "),
                 PokeAccess::Info.info_text
  end

  test "a solved Tile Puzzle board says it is solved" do
    PokeAccess::Minigames.tile_puzzle(tile_puzzle([0, 1, 2, 3]))
    assert_equal t(:tp_solved), PokeAccess::Info.info_text
  end

  test "the cursor's square says where it is, its piece, and whether it is home or how far it is turned" do
    scene = tile_puzzle([0, 3, -1, 1, 2, -1], [0, 0, 0, 1])
    { 0 => [rowcol(1, 1), t(:tp_tile, :n => 1), t(:tp_placed)],
      1 => [rowcol(1, 2), t(:tp_tile, :n => 4), t(:tp_rotated, :deg => 90)],
      2 => [rowcol(2, 1), t(:tp_empty)],
      3 => [rowcol(2, 2), t(:tp_tile, :n => 2)],
      4 => [t(:tp_reserve_left), rowcol(1, 1), t(:tp_tile, :n => 3)],
      5 => [t(:tp_reserve_right), rowcol(1, 1), t(:tp_empty)] }.each do |pos, parts|
      assert_equal parts.join(", "), PokeAccess::Minigames.tp_cell(scene, pos), "square #{pos}"
    end
    turned = tile_puzzle([0, 1, 2, 3], [0, 3, 0, 0])
    assert_equal [rowcol(1, 2), t(:tp_tile, :n => 2), t(:tp_rotated, :deg => 270)].join(", "),
                 PokeAccess::Minigames.tp_cell(turned, 1), "a piece turned on its own square"
  end

  test "with the puzzle help a piece out of place says where it goes, one home does not" do
    scene = tile_puzzle([0, 3, -1, 1, 2, -1])
    PokeAccess::Config.puzzle_assist = true
    assert_equal [rowcol(2, 2), t(:tp_tile, :n => 2), t(:tp_home, :row => 1, :col => 2)].join(", "),
                 PokeAccess::Minigames.tp_cell(scene, 3), "piece 2 belongs on the first row's second square"
    assert_equal [rowcol(1, 1), t(:tp_tile, :n => 1), t(:tp_placed)].join(", "),
                 PokeAccess::Minigames.tp_cell(scene, 0), "piece 1 is home"
  end

  test "a board that does not give its size is taken as four by four" do
    scene = tile_puzzle((0...16).to_a + [-1])
    [:@boardwidth, :@boardheight].each { |iv| scene.remove_instance_variable(iv) }
    assert_equal [rowcol(2, 2), t(:tp_tile, :n => 6), t(:tp_placed)].join(", "),
                 PokeAccess::Minigames.tp_cell(scene, 5), "the sixth square is the second row's second"
    assert_equal [t(:tp_reserve_left), rowcol(1, 1), t(:tp_empty)].join(", "), PokeAccess::Minigames.tp_cell(scene, 16),
                 "the seventeenth is past the board"
  end

  private

  # A spoken text by its key.
  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # A square's row and column as spoken.
  def rowcol(row, col)
    t(:mg_rowcol, :row => row, :col => col)
  end

  # A Voltorb Flip scene on its first level, the cursor on the first row's third card: a Voltorb face down on the first
  # card and one turned up on the fourth, a 3 turned up on the eighth, the fifteenth (a 2) marked, every other card a
  # hidden 1; no column has the sums of the row of its number.
  def voltorb_flip
    values = { 0 => 0, 3 => 0, 7 => 3, 14 => 2 }
    squares = (0...25).map { |i| [i % 5, i / 5, values.fetch(i, 1), i == 3 || i == 7] }
    World.stub_scene(:@index => [2, 0], :@squares => squares, :@marks => [[0, 4 * 64 + 128, 2 * 64]],
                     :@cursor => [[0, 0, 0, 0]], :@points => 3, :@level => 1)
  end

  # A 2x2 Tile Puzzle scene, the cursor on the first square: tiles[pos] is the piece on that square (-1 none; from
  # the fifth on, the reserve) and angles[piece] how far it is turned; it is won, as the game checks it, with every
  # piece on its own square unturned.
  def tile_puzzle(tiles, angles = [0, 0, 0, 0])
    scene = World.stub_scene(:@boardwidth => 2, :@boardheight => 2, :@tiles => tiles, :@angles => angles,
                             :@sprites => { "cursor" => Cursor.new(0) })
    def scene.pbCheckWin
      (0...4).all? { |i| @tiles[i] == i && @angles[i].to_i == 0 }
    end
    scene
  end
end
