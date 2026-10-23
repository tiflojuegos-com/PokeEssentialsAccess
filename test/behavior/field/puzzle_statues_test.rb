# Turning statues (:facing): the declared win said once as it comes, never for one that held on arrival; and, with no
# statue in front, the info key telling them apart by where each stands, nearest first.

class PuzzleStatuesTest < PokeAccessTest
  ROOM = 191
  WIN_SWITCH = 398
  GOALS = { [18, 52] => 4, [12, 7] => 8 }

  test "says the puzzle is solved once the win comes" do
    in_bust_room do
      $game_switches[WIN_SWITCH] = true
      assert_equal [[PokeAccess::I18n.t(:puzzle_solved), false]], frame_log
      assert_equal [], frame_log, "and not again"
    end
  end

  test "keeps quiet about a win that held on arrival" do
    $game_switches[WIN_SWITCH] = true
    in_bust_room do
      assert_equal [], frame_log
    end
  end

  test "tells the busts apart by where each stands when none is in front" do
    t = PokeAccess::I18n
    bust = t.t(:statue_bust)
    south = t.t(:face_south)
    near = t.t(:statue_where, :label => bust, :dist => "1 #{t.t(:dir_up)}", :dir => south)
    far = t.t(:statue_where, :label => bust, :dist => "6 #{t.t(:dir_right)}, 44 #{t.t(:dir_down)}", :dir => south)
    in_bust_room do
      stand(12, 8, 2)
      assert_equal ["#{near}. #{far}"], info_lines
    end
  end

  test "names only the bust in front, without where it stands" do
    t = PokeAccess::I18n
    in_bust_room do
      stand(12, 8, 8)
      assert_equal ["#{t.t(:statue_bust)}: #{t.t(:face_south)}"], info_lines
    end
  end

  private

  def in_bust_room
    was = [$game_map.map_id, $game_player.x, $game_player.y, $game_player.direction]
    PokeAccess::World::Mechanics.define(:facing, ROOM) do
      statues(/malvoBusto/i, :statue_bust)
      goals GOALS
      solved { $game_switches[WIN_SWITCH] }
    end
    $game_map.map_id = ROOM
    World.clear_events
    GOALS.keys.each_with_index do |(x, y), i|
      World.event(:kind => :npc, :id => i + 1, :x => x, :y => y).character_name = "malvoBusto"
    end
    PokeAccess::Caches.reset_all
    frame_log
    yield
  ensure
    $game_switches[WIN_SWITCH] = false
    $game_map.map_id, $game_player.x, $game_player.y, $game_player.direction = was
    World.clear_events
    PokeAccess::Caches.reset_all
  end

  def stand(x, y, dir)
    $game_player.x = x
    $game_player.y = y
    $game_player.direction = dir
  end

  def frame_log
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log
  end

  def info_lines
    PokeAccess::Locator.refresh_info
    SpeakCapture.clear
    PokeAccess::Keys.info_key
    SpeakCapture.lines
  end
end
