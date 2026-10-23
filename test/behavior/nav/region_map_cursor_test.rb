# The region map (core/nav/region_map.rb): the square under the cursor is said when it changes, by its place or its
# coordinates, with the fly mark and the player's head; reopening the map re-reads it, the bottom bar keeps quiet on
# the place just said, and the bar's region name opens the map.
class RegionMapCursorTest < PokeAccessTest
  # A sprite of the map, shown or hidden.
  Icon = Struct.new(:visible)

  test "reads the first square under the cursor, queued" do
    rm.announce(Object.new, "Pueblo Paleta", 3, 4)
    assert_equal [["Pueblo Paleta", false]], SpeakCapture.log
  end

  test "says nothing more while the cursor stays on the square" do
    s = Object.new
    rm.announce(s, "Pueblo Paleta", 3, 4)
    SpeakCapture.clear
    2.times { rm.announce(s, "Pueblo Paleta", 3, 4) }
    assert_nothing_spoken
  end

  test "a move to another square interrupts with its place" do
    s = Object.new
    rm.announce(s, "Pueblo Paleta", 3, 4)
    SpeakCapture.clear
    rm.announce(s, "Ciudad Verde", 4, 4)
    assert_equal [["Ciudad Verde", true]], SpeakCapture.log
  end

  test "the same place on another square is read again" do
    s = Object.new
    rm.announce(s, "Ciudad Verde", 4, 4)
    SpeakCapture.clear
    rm.announce(s, "Ciudad Verde", 4, 5)
    assert_equal ["Ciudad Verde"], SpeakCapture.lines
  end

  test "a square with no place is said by its coordinates" do
    { nil => [5, 4], "" => [6, 4] }.each do |name, (x, y)|
      SpeakCapture.clear
      rm.announce(Object.new, name, x, y)
      assert_equal [t(:brm_square, :x => x, :y => y)], SpeakCapture.lines, "for #{name.inspect}"
    end
  end

  test "a blank square takes the last square's place, so coming back re-reads the town" do
    s = Object.new
    rm.announce(s, "Ciudad Verde", 4, 4)
    rm.announce(s, nil, 5, 4)
    SpeakCapture.clear
    rm.announce(s, "Ciudad Verde", 4, 4)
    assert_equal ["Ciudad Verde"], SpeakCapture.lines
  end

  test "forgetting the scene, as the map opens and closes, reads the same square again as a first read" do
    s = Object.new
    rm.announce(s, "Ciudad Plateada", 7, 2)
    rm.forget(s)
    SpeakCapture.clear
    rm.announce(s, "Ciudad Plateada", 7, 2)
    assert_equal [["Ciudad Plateada", false]], SpeakCapture.log
  end

  test "keeps the last square per scene" do
    first = Object.new
    rm.announce(first, "Ciudad Plateada", 7, 2)
    SpeakCapture.clear
    rm.announce(Object.new, "Ciudad Plateada", 7, 2)
    assert_equal [["Ciudad Plateada", false]], SpeakCapture.log, "a second scene reads the square as its own first"
    SpeakCapture.clear
    rm.announce(first, "Ciudad Plateada", 7, 2)
    assert_nothing_spoken "the first scene still holds it"
  end

  test "on the fly map, a visited town's healing spot says fly is available" do
    with_visited(7 => true) do
      rm.announce(map_scene("point0" => Icon.new(true)), "Pueblo Paleta", 3, 4)
      assert_equal ["Pueblo Paleta, #{t(:brm_fly)}"], SpeakCapture.lines
    end
  end

  test "a healing spot whose map was never visited says no fly mark" do
    with_visited(8 => true) do
      rm.announce(map_scene("point0" => Icon.new(true)), "Pueblo Paleta", 3, 4)
      assert_equal ["Pueblo Paleta"], SpeakCapture.lines
    end
  end

  test "on the fly map, a square with no healing spot says no fly mark" do
    with_visited(7 => true) do
      rm.announce(map_scene("point0" => Icon.new(true)), "Ruta 1", 3, 5)
      assert_equal ["Ruta 1"], SpeakCapture.lines
    end
  end

  test "a healing spot says no fly mark while the map draws no fly icons" do
    with_visited(7 => true) do
      { "no icons" => {}, "icons hidden" => { "point0" => Icon.new(false) } }.each do |what, sprites|
        SpeakCapture.clear
        rm.announce(map_scene(sprites), "Pueblo Paleta", 3, 4)
        assert_equal ["Pueblo Paleta"], SpeakCapture.lines, what
      end
    end
  end

  test "a fly icon with no visibility of its own counts as shown" do
    with_visited(7 => true) do
      rm.announce(map_scene("point0" => Object.new), "Pueblo Paleta", 3, 4)
      assert_equal ["Pueblo Paleta, #{t(:brm_fly)}"], SpeakCapture.lines
    end
  end

  test "switching the town map's fly mode says the help it paints, then the square again with or without its mark" do
    with_visited(7 => true) do
      s = fly_screen
      s.refresh_fly_screen
      rm.announce(s, "Pueblo Paleta", 3, 4)
      said = [1, 0].map do |mode|
        SpeakCapture.clear
        s.instance_variable_set(:@mode, mode)
        s.refresh_fly_screen
        rm.announce(s, "Pueblo Paleta", 3, 4)
        SpeakCapture.log.dup
      end
      assert_equal [[["ACCIÓN: Cancelar Vuelo", true], ["Pueblo Paleta, #{t(:brm_fly)}", false]],
                    [["ACCIÓN: Vuelo", true], ["Pueblo Paleta", false]]], said
    end
  end

  test "the town map opening says the help it paints for its fly mode once, after the player's square" do
    s = fly_screen
    s.instance_variable_get(:@sprites)["player"] = Object.new
    rm.announce(s, "Pueblo Paleta", 3, 4)
    2.times { s.refresh_fly_screen }
    rm.opened(s)
    assert_equal [["Pueblo Paleta", false], [t(:rmap_you), false], ["ACCIÓN: Vuelo", false]], SpeakCapture.log,
                 "a repaint that leaves the mode as it was says nothing"
  end

  test "the fly help said as the town map opens is a key hint, which brief leaves out" do
    said = vb_levels do
      SpeakCapture.clear
      s = fly_screen
      rm.announce(s, "Pueblo Paleta", 3, 4)
      s.refresh_fly_screen
      rm.opened(s)
      SpeakCapture.lines
    end
    assert_equal [["Pueblo Paleta"], ["Pueblo Paleta", "ACCIÓN: Vuelo"], ["Pueblo Paleta", "ACCIÓN: Vuelo"]], said
  end

  test "a wall map, whose action button switches nothing, says no fly help as it opens" do
    s = fly_screen
    s.instance_variable_set(:@wallmap, true)
    rm.announce(s, "Pueblo Paleta", 3, 4)
    s.refresh_fly_screen
    rm.opened(s)
    assert_equal ["Pueblo Paleta"], SpeakCapture.lines
  end

  test "on the fly map, the opening square read before its icons are drawn says it can be flown to once they are" do
    with_visited(7 => true) do
      s = map_scene("player" => Object.new)
      rm.announce(s, "Pueblo Paleta", 3, 4)
      s.instance_variable_get(:@sprites)["point0"] = Icon.new(true)
      rm.opened(s)
      rm.announce(s, "Pueblo Paleta", 3, 4)
      assert_equal [["Pueblo Paleta", false], ["#{t(:brm_fly)}, #{t(:rmap_you)}", false]], SpeakCapture.log
    end
  end

  test "once the map is up with the player's head drawn, says the player is on the opening square, queued" do
    s = map_scene("player" => Object.new)
    rm.announce(s, "Pueblo Paleta", 3, 4)
    rm.opened(s)
    assert_equal [["Pueblo Paleta", false], [t(:rmap_you), false]], SpeakCapture.log
  end

  test "coming back to the opening square says, after the fly mark, that the player is there" do
    with_visited(7 => true) do
      s = map_scene("point0" => Icon.new(true), "player" => Object.new)
      rm.announce(s, "Pueblo Paleta", 3, 4)
      rm.opened(s)
      rm.announce(s, "Ruta 1", 3, 5)
      SpeakCapture.clear
      rm.announce(s, "Pueblo Paleta", 3, 4)
      assert_equal ["Pueblo Paleta, #{t(:brm_fly)}, #{t(:rmap_you)}"], SpeakCapture.lines
    end
  end

  test "a map that draws no player's head says nothing of the player" do
    s = map_scene
    rm.announce(s, "Pueblo Paleta", 3, 4)
    SpeakCapture.clear
    rm.opened(s)
    rm.announce(s, "Ruta 1", 3, 5)
    rm.announce(s, "Pueblo Paleta", 3, 4)
    assert_equal ["Ruta 1", "Pueblo Paleta"], SpeakCapture.lines
  end

  test "says nothing while the map builds, neither the square nor the bar" do
    rm.building do
      rm.announce(map_scene("player" => Object.new), "Bosque Lejano", 10, 5)
      MapBottomSprite.new.maplocation = "Bosque Lejano"
    end
    assert_nothing_spoken
  end

  test "after a silent build, the first square read carries the player's mark" do
    s = map_scene("player" => Object.new)
    rm.building { rm.announce(s, "Bosque Lejano", 10, 5) }
    rm.opened(s)
    rm.announce(s, "Ruta 7", 10, 6)
    assert_equal [["Ruta 7, #{t(:rmap_you)}", false]], SpeakCapture.log, "the opening says nothing until then"
  end

  test "a build that raises still ends the build" do
    assert_raises(RuntimeError) { rm.building { raise "the build failed" } }
    refute rm.building?
  end

  test "the bar painting the place just said keeps quiet" do
    with_visited(7 => true) do
      rm.announce(map_scene("point0" => Icon.new(true)), "Pueblo Paleta", 3, 4)
      SpeakCapture.clear
      MapBottomSprite.new.maplocation = "Pueblo Paleta"
      assert_nothing_spoken
    end
  end

  test "a plugin's place line interrupts unless told otherwise" do
    rm.speak_marked("Ciudad Verde")
    assert_equal [["Ciudad Verde", true]], SpeakCapture.log
  end

  test "a plugin's place line that cleans to nothing is not said and leaves the bar's mark" do
    rm.speak_marked("Ciudad Verde")
    SpeakCapture.clear
    rm.speak_marked("\\c[2]")
    MapBottomSprite.new.maplocation = "Ciudad Verde"
    assert_nothing_spoken
  end

  test "the game asking for a square's place reads it, by its coordinates where it names none" do
    PokemonRegionMapScene.new.pbGetMapLocation(3, 4)
    assert_equal [[t(:brm_square, :x => 3, :y => 4), false]], SpeakCapture.log
  end

  test "starting the map again reads the square under the cursor again" do
    s = PokemonRegionMapScene.new
    s.pbStartScene
    s.pbGetMapLocation(3, 4)
    s.pbEndScene
    s.pbStartScene
    SpeakCapture.clear
    s.pbGetMapLocation(3, 4)
    assert_equal [t(:brm_square, :x => 3, :y => 4)], SpeakCapture.lines
  end

  test "the map takes the jump keys while it is open" do
    s = PokemonRegionMapScene.new
    s.pbStartScene
    open = PokeAccess::TownMap.open_scene
    s.pbEndScene
    assert_equal [s, nil], [open, PokeAccess::TownMap.open_scene], "open on start, free on end"
  end

  test "a menu the map shows while it starts is read" do
    s = PokemonRegionMapScene.new
    menu = Window_DrawableCommand.new(["Volar aquí", "Cancelar"])
    s.instance_variable_set(:@build, lambda { |_scene, _args| menu.update })
    s.pbStartScene
    assert_equal ["Volar aquí"], SpeakCapture.lines
  end

  test "the bar's region name is said, queued, as the map opens" do
    MapBottomSprite.new.mapname = "Kanto"
    assert_equal [["Kanto", false]], SpeakCapture.log
  end

  test "a region name changed with the map up is said on the next frame, after the place" do
    bar = MapBottomSprite.new
    bar.mapname = "Kanto"
    SpeakCapture.clear
    bar.mapname = "Distrito Norte 45%"
    PokeAccess.speak("Ruta 5", true)
    held = SpeakCapture.lines.dup
    PokeAccess::Frame.run_pollers
    assert_equal [["Ruta 5"], ["Ruta 5", "Distrito Norte 45%"]], [held, SpeakCapture.lines]
  end

  private

  def rm
    PokeAccess::RegionMap
  end

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A map scene drawing the given sprites, whose one healing spot is on (3, 4), for map 7.
  def map_scene(sprites = {})
    s = Object.new
    def s.pbGetHealingSpot(x, y); [x, y] == [3, 4] ? [7, 1, 1] : nil; end
    s.instance_variable_set(:@sprites, sprites)
    s
  end

  # The game's town map in view mode (@mode 0), its one healing spot on (3, 4) for map 7 and its fly icon hidden.
  def fly_screen
    s = PokemonRegionMapScene.new
    def s.pbGetHealingSpot(x, y); [x, y] == [3, 4] ? [7, 1, 1] : nil; end
    s.instance_variable_set(:@sprites, "point0" => Icon.new(false))
    s.instance_variable_set(:@mode, 0)
    s
  end

  # Runs the block with the game's record of visited maps answering visited, taken back after.
  def with_visited(visited)
    $PokemonGlobal.define_singleton_method(:visitedMaps) { visited }
    yield
  ensure
    $PokemonGlobal.singleton_class.send(:remove_method, :visitedMaps)
  end
end
