# Control: who holds the player on the map. A hold fires its transitions at once, the pulse sees the player leave the
# map scene, a registered condition holds in its own scope, and the engine's flags hold the cues, the locator keys or
# both, each scope asked in a fixed order of reasons.
class ControlTest < PokeAccessTest
  Control = PokeAccess::Control

  test "free? and keys? say whether nothing holds the cues, and whether nothing locks the locator keys" do
    got = [[Control.free?, Control.keys?],
           Control.hold(:spec_keys, :keys) { [Control.free?, Control.keys?] },
           Control.hold(:spec_cues, :hold) { [Control.free?, Control.keys?] }]
    assert_equal [[true, true], [true, false], [false, true]], got
  end

  test "a hold fires one loss on the way in and one regain on the way out, named by its reason" do
    assert_equal [[:lost, :spec_screen], [:regained, :spec_screen]], transitions { Control.hold(:spec_screen) { nil } }
  end

  test "a hold of both scopes holds the cues and the locator keys while its block runs, and lets go after" do
    inside = Control.hold(:spec_screen) { scopes }
    assert_equal [[:spec_screen, :spec_screen], [nil, nil]], [inside, scopes]
  end

  test "a nested hold of the keys alone takes the keys and leaves the outer hold the cues" do
    assert_equal [:spec_screen, :spec_inner], Control.hold(:spec_screen) { Control.hold(:spec_inner, :keys) { scopes } }
  end

  test "a hold of the keys alone leaves the cues free and fires no transition" do
    inside = nil
    fired = transitions { inside = Control.hold(:spec_keys, :keys) { scopes } }
    assert_equal [[nil, :spec_keys], []], [inside, fired]
  end

  test "a hold whose block raises still lets go, with its regain" do
    fired = transitions { assert_raises(RuntimeError) { Control.hold(:spec_crash) { raise "the screen fails" } } }
    assert_equal [[[:lost, :spec_crash], [:regained, :spec_crash]], [nil, nil]], [fired, scopes]
  end

  test "a reason held twice lets go of its inner hold first" do
    after_inner = Control.hold(:spec_screen) do
      Control.hold(:spec_screen, :keys) { nil }
      scopes
    end
    assert_equal [:spec_screen, :spec_screen], after_inner, "the outer hold of both scopes stands"
  end

  test "the pulse fires the loss once as the player leaves the map scene, and the regain when back" do
    fired = transitions do
      on_scene(Object.new) { 3.times { Control.pulse } }
      Control.pulse
    end
    assert_equal [[:lost, :other_scene], [:regained, :other_scene]], fired
  end

  test "away from the map scene, or with no scene at all, the scene holds both scopes" do
    [Object.new, nil].each do |scene|
      assert_equal [:other_scene, :other_scene], on_scene(scene) { scopes }, "for #{scene.inspect}"
    end
  end

  test "the pulse leaves the engine's flags to the map frame" do
    assert_equal [], transitions { temp_flags(:message_window_showing => true) { Control.pulse } }
  end

  test "a battle the mod saw start holds the cues and leaves the locator keys free" do
    PokeAccess::Battle.battle_started
    assert_equal [:battle, nil], scopes
  end

  test "the reasons are asked in order: the innermost hold, the scene, a battle, the conditions, the engine's flags" do
    seen = keeping_conditions do
      Control.condition(:spec_condition, :hold) { true }
      PokeAccess::Battle.battle_started
      temp_flags(:message_window_showing => true) do
        found = [Control.hold(:spec_screen) { on_scene(Object.new) { Control.reason } },
                 on_scene(Object.new) { Control.reason }, Control.reason]
        PokeAccess::Battle.battle_ended
        found.push(Control.reason)
        Control.condition(:spec_condition, :hold) { false }
        found.push(Control.reason)
      end
    end
    assert_equal [:spec_screen, :other_scene, :battle, :spec_condition, :message], seen
  end

  test "a condition of the keys holds the locator keys and leaves the cues free" do
    got = keeping_conditions do
      Control.condition(:spec_condition, :keys) { true }
      scopes
    end
    assert_equal [nil, :spec_condition], got
  end

  test "a condition registered again replaces the first" do
    got = keeping_conditions do
      Control.condition(:spec_condition, :keys) { true }
      Control.condition(:spec_condition, :hold) { true }
      scopes
    end
    assert_equal [:spec_condition, nil], got
  end

  test "a condition whose probe is false or raises holds nothing" do
    keeping_conditions do
      { "false" => lambda { false }, "raising" => lambda { raise "the probe fails" } }.each do |what, probe|
        Control.condition(:spec_condition, :both, &probe)
        assert_equal [nil, nil], scopes, "a #{what} probe"
      end
    end
  end

  test "each of the engine's own flags holds its scope" do
    { :message_window_showing => [:message, nil], :in_menu => [:in_menu, :in_menu],
      :in_battle => [:in_battle, :in_battle] }.each do |flag, want|
      assert_equal want, temp_flags(flag => true) { scopes }, "for #{flag}"
    end
  end

  test "a move route the game forces on the player holds the cues and leaves the keys free" do
    assert_equal [:move_route, nil], answering($game_player, :move_route_forcing, lambda { true }) { scopes }
  end

  test "a running event holds the cues and leaves the keys free" do
    assert_equal [:interpreter, nil], answering($game_system.map_interpreter, :running?, lambda { true }) { scopes }
  end

  test "an engine with no map interpreter, or no system at all, has no running event to hold the player" do
    [Object.new, nil].each do |system|
      assert_equal [nil, nil], with_system(system) { scopes }, "for #{system.inspect}"
    end
  end

  test "a menu loop updating the map holds the cues, and the keys as an overlay" do
    assert_equal [:mini_update, :overlay], with_pokemon_temp(true) { scopes }
  end

  test "the engine's menu and battle flags fire the transitions as they are set" do
    [:in_menu, :in_battle].each do |flag|
      assert_equal [[:lost, flag], [:regained, flag]], transitions { temp_flags(flag => true) { nil } }, "for #{flag}"
    end
  end

  test "a pushed change never raises into the engine, though a flag's reader fails" do
    assert_nil answering($game_temp, :message_window_showing, lambda { raise "the reader fails" }) { Control.changed! }
  end

  test "an engine object without the flag's reader, or no object, reads as false; a value reads as true" do
    flagged = Object.new
    def flagged.in_menu; "yes"; end
    { Object.new => false, nil => false, flagged => true }.each do |obj, want|
      assert_equal want, Control.flag(obj, :in_menu), "for #{obj.inspect}"
    end
  end

  test "the tile in front of the player follows the way they face, and is their own for a way it does not know" do
    x = $game_player.x
    y = $game_player.y
    { 2 => [x, y + 1], 4 => [x - 1, y], 6 => [x + 1, y], 8 => [x, y - 1], 0 => [x, y] }.each do |dir, tile|
      assert_equal tile, facing(dir) { Control.front_tile }, "facing #{dir}"
    end
  end

  test "is on the map with a map, a player and the map scene, and no menu over it" do
    got = [Control.on_map?, temp_flags(:in_menu => true) { Control.on_map? }, on_scene(Object.new) { Control.on_map? },
           without_player { Control.on_map? }]
    assert_equal [true, false, false, false], got
  end

  test "a Game_Temp with no menu flag, as Insurgence's, leaves the menu flag's hook out of the list of typos" do
    path = File.expand_path("../../../core/input/control.rb", File.dirname(__FILE__))
    line = File.read(path).split("\n").detect { |l| l.include?('after_hook("Game_Temp", :in_menu=') }
    missing = PokeAccess::Hooks.missing
    was = missing.dup
    real = ::Game_Temp
    begin
      Object.send(:remove_const, :Game_Temp)
      Object.const_set(:Game_Temp, Class.new { attr_accessor :in_battle })
      eval(line)
      added = missing - was
    ensure
      Object.send(:remove_const, :Game_Temp)
      Object.const_set(:Game_Temp, real)
      missing.replace(was)
    end
    assert_equal [], added
  end

  private

  # The reasons that hold the player now, for the cues and for the locator keys.
  def scopes
    [Control.reason(:hold), Control.reason(:keys)]
  end

  # The control transitions the block fires, as [:lost or :regained, reason]; the listeners go after.
  def transitions
    seen = []
    lost = proc { |r| seen.push([:lost, r]) }
    regained = proc { |r| seen.push([:regained, r]) }
    PokeAccess::Events.on(:control_lost, &lost)
    PokeAccess::Events.on(:control_regained, &regained)
    yield
    seen
  ensure
    handlers = PokeAccess::Events.instance_variable_get(:@handlers)
    (handlers[:control_lost] || []).reject! { |h| h.equal?(lost) }
    (handlers[:control_regained] || []).reject! { |h| h.equal?(regained) }
  end

  # The block's value with $scene set to scene, the map scene put back after.
  def on_scene(scene)
    was = $scene
    $scene = scene
    yield
  ensure
    $scene = was
  end

  # The block's value with $game_system set to system, the engine's put back after.
  def with_system(system)
    was = $game_system
    $game_system = system
    yield
  ensure
    $game_system = was
  end

  # The block's value with the player facing dir, the way they faced put back after.
  def facing(dir)
    was = $game_player.direction
    $game_player.direction = dir
    yield
  ensure
    $game_player.direction = was
  end

  # The block's value with no player, the player put back after.
  def without_player
    was = $game_player
    $game_player = nil
    yield
  ensure
    $game_player = was
  end

  # The block's value with $game_temp's flags set as given, each put back after through its setter.
  def temp_flags(flags)
    was = flags.keys.map { |f| [f, $game_temp.send(f)] }
    flags.each { |f, v| $game_temp.send("#{f}=", v) }
    yield
  ensure
    (was || []).each { |f, v| $game_temp.send("#{f}=", v) }
  end

  # The block's value with $PokemonTemp answering miniupdate, as gen 6 flags a menu loop updating the map.
  def with_pokemon_temp(miniupdate)
    was = $PokemonTemp
    $PokemonTemp = Struct.new(:miniupdate).new(miniupdate)
    yield
  ensure
    $PokemonTemp = was
  end

  # The block's value with obj's meth answering as body does; the method obj had of its own, if any, put back after.
  def answering(obj, meth, body)
    sc = obj.singleton_class
    own = sc.instance_methods(false).include?(meth) || sc.private_instance_methods(false).include?(meth)
    was = own ? obj.method(meth) : nil
    obj.define_singleton_method(meth, &body)
    yield
  ensure
    if was
      obj.define_singleton_method(meth, was)
    elsif sc && sc.instance_methods(false).include?(meth)
      sc.send(:remove_method, meth)
    end
  end

  # The block's value with Control's registered conditions put back as they were after it.
  def keeping_conditions
    was = Control.instance_variable_get(:@conditions).dup
    yield
  ensure
    Control.instance_variable_set(:@conditions, was)
  end
end
