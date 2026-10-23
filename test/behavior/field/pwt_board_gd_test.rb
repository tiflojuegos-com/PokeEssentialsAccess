# Emerald's PWT scoreboard (PokeAccess::PWT): read once its names are painted, in the order painted, the entrants no
# longer in the running marked as beaten, the player never.
class PwtBoardGdTest < PokeAccessTest
  PWT = PokeAccess::PWT

  test "reads the painted names, queued, the beaten entrants marked" do
    with_board(tourney([:A, :B, :C], [:A, :C])) do
      paint("Yo", "Bruno", "Clara")
      PWT.poll
    end
    assert_equal [[t(:pwt_board, :list => "Yo; Bruno, #{t(:pwt_out)}; Clara"), false]], SpeakCapture.log
  end

  test "reads the board once: the frames after say nothing" do
    with_board(tourney([:A, :B], [:A, :B])) do
      paint("Yo", "Bruno")
      PWT.poll
      SpeakCapture.clear
      PWT.poll
    end
    assert_nothing_spoken
  end

  test "never marks the player, even out of the running list" do
    with_board(tourney([:A, :B], [:B], 0)) do
      paint("Yo", "Bruno")
      PWT.poll
    end
    assert_equal [t(:pwt_board, :list => "Yo; Bruno")], SpeakCapture.lines
  end

  test "a name past the list of entrants is read as painted" do
    with_board(tourney([:A], [:A])) do
      paint("Yo", "Invitado")
      PWT.poll
    end
    assert_equal [t(:pwt_board, :list => "Yo; Invitado")], SpeakCapture.lines
  end

  test "reads only the names painted in place, not the board's other text" do
    with_board(tourney([:A, :B], [:A, :B])) do
      drawTextEx(nil, 0, 0, 256, 1, "Torneo Mundial Pokemon")
      paint("Yo", "Bruno")
      PWT.poll
    end
    assert_equal [t(:pwt_board, :list => "Yo; Bruno")], SpeakCapture.lines
  end

  test "a scoreboard whose running list cannot be read says nothing" do
    board = tourney([:A, :B], [:A])
    board.instance_variable_set(:@trainer_list, [nil])
    with_board(board) do
      paint("Yo", "Bruno")
      PWT.poll
    end
    assert_nothing_spoken
  end

  test "reads the names without the game's text codes" do
    with_board(tourney([:A, :B], [:A, :B])) do
      paint("Yo", "<c3=E82010,F8A8B8>Bruno</c3>")
      PWT.poll
    end
    assert_equal [t(:pwt_board, :list => "Yo; Bruno")], SpeakCapture.lines
  end

  test "says nothing on the frames before the board paints its names, and reads them once painted" do
    with_board(tourney([:A, :B], [:A, :B])) do
      2.times { PWT.poll }
      assert_nothing_spoken "before the names are painted"
      paint("Yo", "Bruno")
      PWT.poll
    end
    assert_equal [t(:pwt_board, :list => "Yo; Bruno")], SpeakCapture.lines
  end

  test "says nothing of names painted with no scoreboard open, before one or after it closed" do
    paint("Yo", "Bruno")
    PWT.poll
    assert_nothing_spoken "before any scoreboard"
    with_board(tourney([:A], [:A])) { nil }
    paint("Yo")
    PWT.poll
    assert_nothing_spoken "after one closed"
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # The tournament (the game's AdvancedWorldTournament) with its entrants by trainer, those still in the running and
  # the player's place among the entrants.
  def tourney(entrants, running, player = 0)
    World.stub_scene(:@trainer_list_int => entrants.map { |e| [e, []] },
                     :@trainer_list => running.map { |e| [e, []] },
                     :@player_index_int => player)
  end

  # Paints the names down the board, as displayScoreboard does.
  def paint(*names)
    pbDrawTextPositions(nil, names.each_with_index.map { |n, i| [n, 34, 38 + 64 * i] })
  end

  # Runs the block with the scoreboard of tourney open, closed after.
  def with_board(tourney)
    PWT.open(tourney)
    yield
  ensure
    PWT.close
  end
end
