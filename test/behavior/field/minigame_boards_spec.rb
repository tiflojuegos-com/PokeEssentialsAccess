# The info key reads the whole board: Voltorb Flip's rows and columns, and where every piece of a tile puzzle is.

class BoardsSpecCursor
  attr_accessor :position
  def initialize(pos); @position = pos; end
end

# A 2x2 tile puzzle scene: tiles[pos] is the piece on that square, solved when every piece is on its own.
def boards_tp_scene(cursor_pos, tiles)
  s = Object.new
  s.instance_variable_set(:@boardwidth, 2)
  s.instance_variable_set(:@boardheight, 2)
  s.instance_variable_set(:@tiles, tiles)
  s.instance_variable_set(:@angles, [0, 0, 0, 0])
  s.instance_variable_set(:@sprites, { "cursor" => BoardsSpecCursor.new(cursor_pos) })
  def s.pbCheckWin
    t = instance_variable_get(:@tiles)
    (0...t.length).all? { |i| t[i] == i }
  end
  s
end

Suite.define("minigames: the info key reads the whole Voltorb Flip board") do
  squares = (0...25).map { |i| [i % 5, i / 5, (i == 0 ? 0 : (i == 6 ? 3 : 1)), i == 6] }
  scene = Object.new
  scene.instance_variable_set(:@index, [1, 1])
  scene.instance_variable_set(:@squares, squares)
  scene.instance_variable_set(:@marks, [])
  scene.instance_variable_set(:@cursor, [[0, 0, 0, 0]])
  scene.instance_variable_set(:@points, 3)
  scene.instance_variable_set(:@level, 1)
  t = PokeAccess::I18n
  PokeAccess::Minigames.voltorb_flip(scene)
  board = PokeAccess::Info.info_text.to_s
  hidden = t.t(:mg_hidden)
  row1 = t.t(:mg_board_row, :n => 1, :cells => ([hidden] * 5).join(", "), :sum => 4, :voltorbs => 1)
  row2 = t.t(:mg_board_row, :n => 2, :cells => [hidden, "3", hidden, hidden, hidden].join(", "), :sum => 7, :voltorbs => 0)
  truthy "the first row, its cards hidden, with its sum and Voltorbs", board.include?(row1)
  truthy "the second row shows the card turned up", board.include?(row2)
  truthy "then each column", board.include?(t.t(:mg_board_col, :n => 1, :sum => 4, :voltorbs => 1))
  PokeAccess::Info.clear_text
end

Suite.define("minigames: the info key reads the whole tile puzzle, and help says where a piece goes") do
  t = PokeAccess::I18n
  scene = boards_tp_scene(0, [2, 1, 0, 3])
  PokeAccess::Minigames.tile_puzzle(scene)
  board = PokeAccess::Info.info_text.to_s
  truthy "the first row, the piece already home said to be", board.include?(
    t.t(:tp_board_row, :n => 1, :cells => [t.t(:tp_tile, :n => 3), t.t(:tp_tile, :n => 2) + " " + t.t(:tp_placed)].join(", ")))
  truthy "and how many are still out of place", board.include?(t.t(:tp_wrong, :n => 2))
  had = PokeAccess::Config.puzzle_assist
  begin
    PokeAccess::Config.puzzle_assist = false
    falsy "without the puzzle help a piece does not say where it belongs",
          PokeAccess::Minigames.tp_cell(scene, 0).include?(t.t(:tp_home, :row => 2, :col => 1))
    PokeAccess::Config.puzzle_assist = true
    truthy "with it, it does", PokeAccess::Minigames.tp_cell(scene, 0).include?(t.t(:tp_home, :row => 2, :col => 1))
  ensure
    PokeAccess::Config.puzzle_assist = had
    PokeAccess::Info.clear_text
  end
end
