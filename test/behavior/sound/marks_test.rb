# The player's marks as a sonar kind (:mark): this map's in the sonar's range (in sight in hide mode), nearest first,
# pinging at settings of their own, and read again on the frame after a change to them.
class SoundMarksTest < PokeAccessTest
  Scene = PokeAccess::Sound::Scene
  Marks = PokeAccess::Marks

  test "a scan finds this map's marks within the sonar's range, nearest first" do
    PokeAccess::Config.audio3d_range = 6
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      Marks.set(1, 5, 9, "Salida")
      Marks.set(1, 20, 20, "Lejos")
      Marks.set(2, 6, 5, "Otro mapa")
      Scene.scan(5, 5)
      assert_equal [[7, 5], [5, 9]], Scene.emitters[:mark]
    end
  end

  test "a mark at the edge of the sonar's range pings, one tile past it does not" do
    PokeAccess::Config.audio3d_range = 6
    with_marks do
      Marks.set(1, 11, 5, "Borde")
      Marks.set(1, 5, 12, "Fuera")
      Scene.scan(5, 5)
      assert_equal [[11, 5]], Scene.emitters[:mark]
    end
  end

  test "in hide mode a mark behind a wall is left out" do
    with_marks do
      walled_marks
      Scene.scan(1, 1)
      assert_equal [[1, 3]], Scene.emitters[:mark]
    end
  end

  test "heard through walls, a mark behind one pings too" do
    PokeAccess::Config.audio3d_occlusion = :hear
    with_marks do
      walled_marks
      Scene.scan(1, 1)
      assert_equal [[1, 3], [5, 1]], Scene.emitters[:mark]
    end
  end

  test "two marks side by side under different names both ping" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      Marks.set(1, 8, 5, "Taller")
      Scene.scan(5, 5)
      assert_equal [[7, 5], [8, 5]], Scene.emitters[:mark]
    end
  end

  test "with no marks on the map the kind has no emitters" do
    with_marks do
      Marks.set(2, 6, 5, "Otro mapa")
      Scene.scan(5, 5)
      assert_nil Scene.emitters[:mark]
    end
  end

  test "a mark pings on a channel of its own at the marks' volume" do
    PokeAccess::Config.audio3d_mark = 37
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      with_frame do |dll, sch|
        sch.tick
        assert_equal [[:mark, 7, 5, 37]], dll.played
      end
    end
  end

  test "a mark's channel takes the marks' tone, the objects' keeping theirs" do
    PokeAccess::Config.audio3d_tone_mark = 100
    with_marks do
      with_frame do |dll, sch|
        sch.tick
        pitches = dll.by_sound(:pitch)
        assert_equal [[:mark, 200], [:object, 100]], [pitches.assoc(:mark), pitches.assoc(:object)], "an octave up"
      end
    end
  end

  test "a mark pings again at the marks' pace, not the objects'" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      { [100, 0] => [[[7, 5]], [[7, 5]]], [0, 100] => [[[7, 5]], []] }.each do |(marks, objects), want|
        PokeAccess::Config.audio3d_freq_mark = marks
        PokeAccess::Config.audio3d_freq_object = objects
        with_frame do |dll, sch|
          Scene.scan(5, 5)
          got = [10.0, 10.5].map { |t| dll.log.clear; sch.ping(t); dll.tiles }
          assert_equal want, got, "half a second apart, the marks' frequency at #{marks}, the objects' at #{objects}"
        end
      end
    end
  end

  test "the marks' switch silences them, the objects' switch leaves them pinging" do
    PokeAccess::Config.audio3d_mark = 37
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      { [false, true] => [], [true, false] => [[:mark, 7, 5, 37]] }.each do |(marks, objects), want|
        PokeAccess::Config.sound_marks = marks
        PokeAccess::Config.sound_objects = objects
        with_frame do |dll, sch|
          sch.tick
          assert_equal want, dll.played, "the marks #{marks ? 'on' : 'off'}, the objects #{objects ? 'on' : 'off'}"
        end
      end
    end
  end

  test "a change to the marks reads the scene again on the next frame, the player still on the same tile" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      Marks.set(1, 5, 9, "Salida")
      with_frame do |_dll, sch|
        sch.tick
        Marks.delete(1, 7, 5)
        sch.tick
        assert_equal [[7, 5], [5, 9]], Scene.emitters[:mark], "untold, the frame keeps the reading of this tile"
        PokeAccess::Events.emit(:tags_changed)
        sch.tick
        assert_equal [[5, 9]], Scene.emitters[:mark], "told of the change, the next frame reads the scene again"
      end
    end
  end

  private

  # Runs the block with the marks store empty, and empties it again after.
  def with_marks
    wipe_marks
    yield
  ensure
    wipe_marks
  end

  # Deletes the marks files and forgets the store.
  def wipe_marks
    [Marks::FILE, Marks::IMPORT, Marks::EXPORT].each { |f| File.delete(f) if File.exist?(f) }
    Marks.reload!
  end

  # A room split by a wall with the player at its top left, a mark behind the wall to the east and one in sight below.
  def walled_marks
    $game_map.load_grid(["#######",
                         "#@.#..#",
                         "#..#..#",
                         "#.....#",
                         "#######"])
    Marks.set(1, 5, 1, "Tras el muro")
    Marks.set(1, 1, 3, "A la vista")
  end

  # Runs the block (given the dll's shadow and the scheduler) with a trainer standing in for the game's, the engine
  # booted and the soundscape fresh; with no trainer, the appearance screen holds control.
  def with_frame
    trainer = $Trainer
    $Trainer = Object.new
    with_sound_engine { |dll| with_soundscape { |sch, _sc| yield dll, sch } }
  ensure
    $Trainer = trainer
  end
end
