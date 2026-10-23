# Infinite Fusion's move tutor board (pbShowRareTutorFullList, games/infinitefusion_common/moves_list.rb), gamedata
# pass: the relearner opened with no Pokemon, a list to browse; each move reads its own data, its title leading once.
class IfMovesListGdTest < PokeAccessTest
  PROFILE = File.join(Harness::ROOT, "games", "infinitefusion_common", "moves_list.rb")

  # MoveList.title as core defines it and as the profile overrides it: the profile is evaluated once, its title put
  # back to core's at once and put in place only by the tests that read the board under it.
  CORE_TITLE = PokeAccess::MoveList.method(:title)
  eval(Harness.source(PROFILE), TOPLEVEL_BINDING, PROFILE)
  BOARD_TITLE = PokeAccess::MoveList.method(:title)
  PokeAccess::MoveList.define_singleton_method(:title, CORE_TITLE)

  test "reads a move on the board, with no Pokemon to teach, from its own data" do
    PokeAccess::MoveList.detail(relearner(nil, [:TACKLE, :EMBER]))
    assert_equal [[move_line(:TACKLE), true]], SpeakCapture.log
  end

  test "leads the board's first move with its title, and says the next move alone" do
    board = relearner(nil, [:TACKLE, :EMBER])
    with_board_title do
      PokeAccess::MoveList.detail(board)
      board.instance_variable_get(:@sprites)["commands"].index = 1
      PokeAccess::MoveList.detail(board)
    end
    assert_equal ["Moves list. #{move_line(:TACKLE)}", move_line(:EMBER)], SpeakCapture.lines
  end

  test "says the board's title in the game's translation" do
    with_board_title { with_intl("Moves list" => "Lista de movimientos") { PokeAccess::MoveList.detail(relearner(nil, [:TACKLE])) } }
    assert_equal ["Lista de movimientos. #{move_line(:TACKLE)}"], SpeakCapture.lines
  end

  test "gives no board title to a relearner teaching a Pokemon" do
    with_board_title { PokeAccess::MoveList.detail(relearner(Poke.build(:name => "Chispa"), [:TACKLE])) }
    assert_equal [move_line(:TACKLE)], SpeakCapture.lines
  end

  private

  # A move's line as the board says it from the stub's data: its name, type, category, power, accuracy and
  # description.
  def move_line(id)
    t = PokeAccess::I18n
    ["Move#{id}", t.t(:mv_type, :t => "TypeTYPE1"), t.t(:cat_physical), t.t(:mv_power, :p => "40"),
     t.t(:mv_acc, :a => 100), "desc#{id}"].join(". ")
  end

  # A relearner scene with its moves, its cursor on one of them, and the Pokemon it teaches (nil on the board).
  def relearner(pokemon, moves, index = 0)
    World.stub_scene(:@pokemon => pokemon, :@moves => moves, :@sprites => { "commands" => Struct.new(:index).new(index) })
  end

  # Runs the block with the profile's board title in place, core's put back afterwards.
  def with_board_title
    PokeAccess::MoveList.define_singleton_method(:title, BOARD_TITLE)
    yield
  ensure
    PokeAccess::MoveList.define_singleton_method(:title, CORE_TITLE)
  end
end
