# Map borders a game crosses by script (Locator::SCRIPT_EDGES): one exit a side the profile says leads on, on the tile
# inside the open border nearest its middle, named by its way and numbered clockwise from the top, and its arrival line.
class ScriptEdgesTest < PokeAccessTest
  Loc = PokeAccess::Locator
  ROOM = ["####.####", "#.......#", "#.......#", "..@......", "#.......#", "#.......#", "#########"]

  test "lists an exit a side the profile names, inside the open border nearest its middle, clockwise from the top" do
    room_map(ROOM)
    mid = $game_map.map_id
    with_sides(lambda { |id| id == mid ? [2, 4, 6, 8] : nil }) do
      got = Loc.connection_targets.map { |t| [t.x, t.y, t.ref, Loc.target_name(t)] }
      assert_equal [[4, 1, -4, t(:loc_exit_out, :out => t(:loc_out_up))],
                    [7, 3, -3, t(:loc_exit_out, :out => t(:loc_out_right))],
                    [1, 3, -1, t(:loc_exit_out, :out => t(:loc_out_left))]], got
    end
  end

  test "takes of a long open border the tile nearest its middle" do
    room_map(["##.....##", "#.......#", "#.@.....#", "#########"])
    with_sides(lambda { |_id| [8] }) do
      assert_equal [[4, 1]], Loc.connection_targets.map { |t| [t.x, t.y] }
    end
  end

  test "lists no script edge on a map the profile does not run, nor with no profile asking" do
    room_map(ROOM)
    assert_equal [], Loc.connection_targets
    with_sides(lambda { |_id| nil }) { assert_equal [], Loc.connection_targets }
  end

  test "on a script edge's tile the arrival says which way to step out onto the border" do
    room_map(ROOM)
    with_sides(lambda { |_id| [4] }) do
      left = Loc.connection_targets[0]
      $game_player.x = 1
      $game_player.y = 3
      assert_equal t(:loc_arrived_exit, :exit => t(:loc_exit_out, :out => t(:loc_out_left))), Loc.arrived_line(left)
    end
  end

  test "shows the script edges among the exits" do
    room_map(ROOM)
    with_sides(lambda { |_id| [4, 6] }) do
      names = Loc.candidates(:exits).select { |e| Loc.edge?(e) }.map { |e| Loc.target_name(e) }
      assert_equal [t(:loc_exit_out, :out => t(:loc_out_left)), t(:loc_exit_out, :out => t(:loc_out_right))].sort,
                   names.sort
    end
  end

  private

  # A text of the mod's.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Lays rows out, the player on '@', and drops the routes kept.
  def room_map(rows)
    $game_map.load_grid(rows)
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # Runs the block with blk as the only script-edge declaration.
  def with_sides(blk)
    saved = Loc::SCRIPT_EDGES.dup
    Loc::SCRIPT_EDGES.replace([blk])
    yield
  ensure
    Loc::SCRIPT_EDGES.replace(saved)
  end
end
