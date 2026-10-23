# The mini update (a menu over the map that sets no in_menu, such as Insurgence's pause menu: $PokemonTemp.miniupdate
# up to v20, $game_temp.in_mini_update from v21) holds the player and takes the locator keys, unless a message is up.
class MiniUpdateBusyTest < PokeAccessTest
  Control = PokeAccess::Control
  MiniTemp = Struct.new(:miniupdate)

  test "a menu over the map holds the player and takes the locator keys" do
    with_pokemon_temp(MiniTemp.new(true)) do
      assert_equal [:mini_update, :overlay], reasons
      assert_equal [false, false], [Control.free?, Control.keys?], "neither the cues nor the locator keys are free"
    end
  end

  test "v21's in_mini_update holds the player and takes the locator keys alike" do
    with_pokemon_temp(nil) do
      with_v21_mini_update { assert_equal [:mini_update, :overlay], reasons }
    end
  end

  test "with the flag down, or no flag to read, nothing holds the player" do
    temps = { "flag down" => MiniTemp.new(false), "no miniupdate reader" => Object.new, "no $PokemonTemp" => nil }
    temps.each do |what, temp|
      with_pokemon_temp(temp) do
        assert_equal [nil, nil], reasons, what
        assert_equal [true, true], [Control.free?, Control.keys?], "#{what}: the cues and the locator keys are free"
      end
    end
  end

  test "a message during it leaves the locator keys free and holds the cues as a message" do
    with_pokemon_temp(MiniTemp.new(true)) do
      with_game_temp(:message_window_showing) { assert_equal [:message, nil], reasons }
    end
  end

  test "an open menu or a battle keeps the locator keys through a message, where the mini update lets them go" do
    with_pokemon_temp(MiniTemp.new(true)) do
      [:in_menu, :in_battle].each do |flag|
        with_game_temp(flag) do
          with_game_temp(:message_window_showing) { assert_equal [:message, flag], reasons, "#{flag} up" }
        end
      end
    end
  end

  test "the map frame reports control lost once as it opens, and regained as it closes" do
    log = transitions do |seen|
      with_pokemon_temp(MiniTemp.new(true)) { 2.times { Control.evaluate } }
      assert_equal [[:lost, :mini_update]], seen, "lost once over two frames under the menu"
      with_pokemon_temp(nil) { Control.evaluate }
    end
    assert_equal [[:lost, :mini_update], [:regained, :mini_update]], log, "regained on the frame after it closes"
  end

  private

  # What holds the cues and what locks the locator keys now, as [hold reason, keys reason].
  def reasons
    [Control.reason(:hold), Control.reason(:keys)]
  end

  # Runs the block with $PokemonTemp set to temp, the one before put back after.
  def with_pokemon_temp(temp)
    was = $PokemonTemp
    $PokemonTemp = temp
    yield
  ensure
    $PokemonTemp = was
  end

  # Runs the block with one of $game_temp's flags up through its setter, as the engine raises it, put back after.
  def with_game_temp(flag)
    was = $game_temp.send(flag)
    $game_temp.send("#{flag}=", true)
    yield
  ensure
    $game_temp.send("#{flag}=", was)
  end

  # Runs the block with v21's in_mini_update up on $game_temp, whose stub has no such flag; taken off again after.
  def with_v21_mini_update
    sc = $game_temp.singleton_class
    sc.send(:attr_accessor, :in_mini_update)
    $game_temp.in_mini_update = true
    yield
  ensure
    sc.send(:remove_method, :in_mini_update, :in_mini_update=)
    $game_temp.send(:remove_instance_variable, :@in_mini_update)
  end

  # The [:lost or :regained, reason] transitions control emits while the block runs, yielded to it as they come.
  def transitions
    log = []
    lost = proc { |r| log.push([:lost, r]) }
    regained = proc { |r| log.push([:regained, r]) }
    PokeAccess::Events.on(:control_lost, &lost)
    PokeAccess::Events.on(:control_regained, &regained)
    yield log
    log
  ensure
    handlers = PokeAccess::Events.instance_variable_get(:@handlers)
    handlers[:control_lost].delete(lost)
    handlers[:control_regained].delete(regained)
  end
end
