# The ledge's tick (Sound::Feedback.ledge): on by default and silent with its switch off; it plays on the ledge's tile,
# once each time the player comes to face a ledge they can jump, and never from the side it cannot be jumped from nor
# toward floor.
class LedgeTest < PokeAccessTest
  Feedback = PokeAccess::Sound::Feedback

  test "plays by default, at the jumps' volume, as the player comes to face a ledge" do
    in_ledge_room do |dll|
      face(2, 1, 2)
      assert_equal [[:ledge, 2, 2, 70]], ledge_ticks(dll)
    end
  end

  test "is silent with its switch off" do
    PokeAccess::Config.sound_ledges = false
    in_ledge_room do |dll|
      face(2, 1, 2)
      assert_equal [], ledge_ticks(dll)
    end
  end

  test "switched on, it plays on the ledge's tile at the jumps' volume as the player comes to face it" do
    PokeAccess::Config.sound_ledges = true
    PokeAccess::Config.jump_volume = 45
    in_ledge_room do |dll|
      face(2, 1, 2)
      assert_equal [[:ledge, 2, 2, 45]], ledge_ticks(dll)
    end
  end

  test "plays once while the player keeps facing the ledge" do
    PokeAccess::Config.sound_ledges = true
    in_ledge_room do |dll|
      face(2, 1, 2)
      face(2, 1, 2)
      assert_equal 1, ledge_ticks(dll).length
    end
  end

  test "plays again when the player turns away and back" do
    PokeAccess::Config.sound_ledges = true
    in_ledge_room do |dll|
      face(2, 1, 2)
      face(2, 1, 8)
      face(2, 1, 2)
      assert_equal 2, ledge_ticks(dll).length
    end
  end

  test "is silent facing the ledge from below, where it cannot be jumped" do
    PokeAccess::Config.sound_ledges = true
    in_ledge_room do |dll|
      face(2, 3, 8)
      assert_equal [], ledge_ticks(dll)
    end
  end

  test "is silent facing open floor" do
    PokeAccess::Config.sound_ledges = true
    in_ledge_room do |dll|
      face(1, 1, 2)
      assert_equal [], ledge_ticks(dll)
    end
  end

  test "is silent with sound navigation off" do
    PokeAccess::Config.sound_ledges = true
    PokeAccess::Config.sound_nav = :off
    in_ledge_room do |dll|
      face(2, 1, 2)
      assert_equal [], ledge_ticks(dll)
    end
  end

  private

  # Runs the block with the engine's shadow (yielded) in a room two tiles wide whose right column has, on its middle
  # row, a ledge jumped downward; the player's facing is put back after.
  def in_ledge_room
    facing = $game_player.direction
    $game_map.load_grid(["####",
                         "#..#",
                         "#..#",
                         "#..#",
                         "####"])
    $game_map.place_ledge(2, 2, 2)
    with_sound_engine { |dll| yield dll }
  ensure
    $game_player.direction = facing
  end

  # Stands the player on (x, y) facing dir, and runs the ledge's tick as a map frame does.
  def face(x, y, dir)
    $game_player.x = x
    $game_player.y = y
    $game_player.direction = dir
    Feedback.ledge
  end

  # The ledge's ticks the engine played, as [sound, x, y, volume].
  def ledge_ticks(dll)
    dll.played.select { |sound, _x, _y, _vol| sound == :ledge }
  end
end
