# The map's name, said once on entering a map and again only on a new map id, a load or a forgotten map; where it
# comes from: the player's rename, else MapInfos, cleaned for speech (Locator.announce_map_change and map_name); and
# Shift+M, which renames the map or restores the game's name (Locator.rename_map).
class MapChangeTest < PokeAccessTest
  test "names the map queued on entering it, once however many frames pass" do
    $game_map.map_id = 35
    10.times { locator.announce_map_change }
    assert_equal [["Mapa 35", false]], SpeakCapture.log
  end

  test "names the new map once the map id changes" do
    $game_map.map_id = 35
    locator.announce_map_change
    SpeakCapture.clear
    $game_map.map_id = 40
    5.times { locator.announce_map_change }
    assert_equal [["Mapa 40", false]], SpeakCapture.log
  end

  test "a load, a new map object on the same id, names the map again" do
    $game_map.map_id = 35
    locator.announce_map_change
    SpeakCapture.clear
    with_game_map($game_map.dup) do
      2.times { locator.announce_map_change }
      assert_equal [["Mapa 35", false]], SpeakCapture.log
    end
  end

  test "a new map or a load resets every cache once, and standing on it none again" do
    with_reset_count do |runs|
      $game_map.map_id = 35
      3.times { locator.announce_map_change }
      assert_equal 1, runs[0], "entering the map"
      with_game_map($game_map.dup) do
        3.times { locator.announce_map_change }
        assert_equal 2, runs[0], "a load onto it"
      end
    end
  end

  test "tells of the change before naming the map, and that it is named after" do
    heard = []
    with_listener(:map_changed, lambda { |mid| heard.push([:map_changed, mid, SpeakCapture.lines.dup]) }) do
      with_listener(:map_named, lambda { |mid| heard.push([:map_named, mid, SpeakCapture.lines.dup]) }) do
        $game_map.map_id = 35
        locator.announce_map_change
      end
    end
    assert_equal [[:map_changed, 35, []], [:map_named, 35, ["Mapa 35"]]], heard
  end

  test "a forgotten map is named again on the next frame" do
    $game_map.map_id = 35
    locator.announce_map_change
    SpeakCapture.clear
    locator.forget_map
    locator.announce_map_change
    assert_equal [["Mapa 35", false]], SpeakCapture.log
  end

  test "a forgotten map takes the player's next place as where they start, not as a teleport" do
    $game_map.map_id = 35
    locator.announce_internal_teleport
    locator.forget_map
    $game_player.x = 15
    $game_player.y = 15
    locator.announce_internal_teleport
    assert_nothing_spoken
  end

  test "entering a map with no name says nothing" do
    $game_map.map_id = 777
    locator.announce_map_change
    assert_nothing_spoken
  end

  test "with no map there is nothing to name" do
    with_game_map(nil) { locator.announce_map_change }
    assert_nothing_spoken
  end

  test "a map is named from MapInfos, and an id it lacks not at all" do
    assert_equal "Mapa 35", locator.map_name(35)
    assert_nil locator.map_name(999999)
  end

  test "the player's rename wins over the MapInfos name" do
    PokeAccess::MapNames.set(35, "Pueblo del faro")
    assert_equal "Pueblo del faro", locator.map_name(35)
  ensure
    PokeAccess::MapNames.delete(35)
  end

  test "a map name is cleaned for speech, the player's name in place of \\PN" do
    assert_equal "Casa de #{$Trainer.name}", locator.map_name(36)
  end

  test "Shift+M on a map the player named offers renaming it, restoring the game's name and going back" do
    renamed_map("Pueblo del faro") do
      asked = choosing(2) { locator.rename_map }
      t = PokeAccess::I18n
      assert_equal [[t.t(:map_menu, :name => "Pueblo del faro"), [t.t(:tag_rename), t.t(:map_restore), t.t(:back)], 3]],
                   asked
      assert_equal ["Pueblo del faro", []], [PokeAccess::MapNames.get(35), SpeakCapture.log], "going back changes nothing"
    end
  end

  test "restoring the game's name from Shift+M's menu forgets the player's one, and says so" do
    renamed_map("Pueblo del faro") do
      choosing(1) { locator.rename_map }
      assert_equal ["Mapa 35", [[PokeAccess::I18n.t(:map_label_removed), true]]], [locator.map_name(35), SpeakCapture.log]
    end
  end

  test "Escape on Shift+M's prompt, or a blank name, keeps the player's name for the map and says nothing changed" do
    renamed_map("Pueblo del faro") do
      ["", "  "].each do |answer|
        SpeakCapture.clear
        GameFunctions.with(:pbEnterText => lambda { |*_args| answer }) { choosing(0) { locator.rename_map } }
        assert_equal "Pueblo del faro", PokeAccess::MapNames.get(35), answer.inspect
        assert_equal [[PokeAccess::I18n.t(:map_label_for, :name => "Pueblo del faro"), true],
                      [PokeAccess::I18n.t(:cancelled), true]], SpeakCapture.log, answer.inspect
      end
    end
  end

  test "Shift+M on a map the player never named asks for its name straight away" do
    renamed_map(nil) do
      asked = choosing(2) { GameFunctions.with(:pbEnterText => lambda { |*_args| "Faro" }) { locator.rename_map } }
      assert_equal [[], "Faro"], [asked, PokeAccess::MapNames.get(35)]
    end
  end

  private

  # The module under test.
  def locator
    PokeAccess::Locator
  end

  # Runs the block on map 35, named name by the player (nil: never renamed), with the log cleared; its name forgotten
  # after.
  def renamed_map(name)
    $game_map.map_id = 35
    PokeAccess::MapNames.set(35, name) if name
    SpeakCapture.clear
    yield
  ensure
    PokeAccess::MapNames.delete(35)
  end

  # Runs the block with every choice message picking index, through the Kernel.pbMessage the menus prefer; returns
  # what each message asked, as [text, choices, cancel index].
  def choosing(index)
    asked = []
    real = Kernel.method(:pbMessage)
    Kernel.define_singleton_method(:pbMessage) { |msg, choices = nil, cancel = nil| asked.push([msg, choices, cancel]); index }
    yield
    asked
  ensure
    Kernel.define_singleton_method(:pbMessage, real)
  end

  # Runs the block with $game_map set to map, the test map put back after.
  def with_game_map(map)
    was = $game_map
    $game_map = map
    yield
  ensure
    $game_map = was
  end

  # Runs the block with a cache registered that counts its resets in runs[0], taken out after.
  def with_reset_count
    runs = [0]
    PokeAccess::Caches.register(:map_change_test_probe) { runs[0] += 1 }
    yield runs
  ensure
    PokeAccess::Caches.instance_variable_get(:@resets).reject! { |r| r[0] == :map_change_test_probe }
  end

  # Runs the block with handler subscribed to the mod's event name, unsubscribed after.
  def with_listener(name, handler)
    PokeAccess::Events.on(name, &handler)
    yield
  ensure
    PokeAccess::Events.instance_variable_get(:@handlers)[name].delete(handler)
  end
end
