# A profile's diagnostic section joins the full dump and its debug-menu group once; diag_build runs the sections
# asked for in order, a raise as an ERR line; visible_caps lists the true capabilities and the engine globals.
class DiagSectionTest < PokeAccessTest
  Keys = PokeAccess::Keys
  HEADER = /\A=== PokeAccess diag .+ ===\z/

  test "joins the full dump and the debug-menu group it names" do
    kept_sections do
      group = Keys::DIAG_SECTIONS[:perf].dup
      Keys.register_diag_section(:probe_named, :perf) { |o| o.push("named") }
      assert_equal :probe_named, Keys::DIAG_ALL.last, "the full dump runs it last"
      assert_equal group + [:probe_named], Keys::DIAG_SECTIONS[:perf]
    end
  end

  test "joins the scene group when it names none" do
    kept_sections do
      group = Keys::DIAG_SECTIONS[:scene].dup
      Keys.register_diag_section(:probe_unnamed) { |o| o.push("unnamed") }
      assert_equal group + [:probe_unnamed], Keys::DIAG_SECTIONS[:scene]
    end
  end

  test "joins only the full dump when its group does not exist" do
    kept_sections do
      groups = Keys::DIAG_SECTIONS.map { |g, list| [g, list.dup] }
      Keys.register_diag_section(:probe_orphan, :no_such_group) { |o| o.push("orphan") }
      assert_equal :probe_orphan, Keys::DIAG_ALL.last
      assert_equal groups, Keys::DIAG_SECTIONS.map { |g, list| [g, list] }, "no group changed"
    end
  end

  test "takes a name given as text for the same section" do
    kept_sections do
      Keys.register_diag_section("probe_text", :perf) { |o| o.push("from text") }
      assert_equal :probe_text, Keys::DIAG_ALL.last
      assert_equal ["from text"], dump_lines([:probe_text])
    end
  end

  test "registered again, replaces its block and stays listed once" do
    kept_sections do
      Keys.register_diag_section(:probe_again, :perf) { |o| o.push("v1") }
      Keys.register_diag_section(:probe_again, :perf) { |o| o.push("v2") }
      assert_equal [1, 1], [Keys::DIAG_ALL.count(:probe_again), Keys::DIAG_SECTIONS[:perf].count(:probe_again)]
      assert_equal ["v2"], dump_lines([:probe_again])
    end
  end

  test "dumps a stamped header, then each section asked for in that order" do
    kept_sections do
      Keys.register_diag_section(:probe_first) { |o| o.push("first") }
      Keys.register_diag_section(:probe_second) { |o| o.push("second", "second, more") }
      lines = Keys.diag_build([:probe_second, :probe_first]).split("\n")
      assert_match HEADER, lines[0]
      assert_equal ["second", "second, more", "first"], lines[1..-1]
    end
  end

  test "turns a raising section into an ERR line and goes on with the rest" do
    kept_sections do
      Keys.register_diag_section(:probe_before) { |o| o.push("before") }
      Keys.register_diag_section(:probe_broken) { |_o| raise "boom" }
      Keys.register_diag_section(:probe_after) { |o| o.push("after") }
      assert_equal ["before", "probe_broken: ERR RuntimeError: boom", "after"],
                   dump_lines([:probe_before, :probe_broken, :probe_after])
    end
  end

  test "runs a section no profile registered as the Keys method of its name" do
    assert_match(/\Ainput_update_layers: \[.*\] frame_pollers=\d+\z/, dump_lines([:diag_polls]).join("\n"))
  end

  test "lists the capabilities that answer true, sorted, bar the three the engine line states" do
    yes = lambda { true }
    caps = { :gen6 => yes, :gamedata => yes, :sky_fork => yes, :zeta_cap => yes, :alpha_cap => yes,
             :off_cap => lambda { false } }
    with_capabilities(caps) do
      with_engine_globals(nil, nil, false) do
        assert_equal ["alpha_cap", "zeta_cap"], Keys.visible_caps(PokeAccess::Engine)
      end
    end
  end

  test "adds the gen-6 battle scene and the player globals when they exist" do
    with_capabilities({}) do
      with_engine_globals(Object.new, Object.new, true) do
        assert_equal ["PokeBattle_Scene", "$player", "$Trainer"], Keys.visible_caps(PokeAccess::Engine)
      end
    end
  end

  private

  # The lines diag_build writes for sections, its header aside.
  def dump_lines(sections)
    lines = Keys.diag_build(sections).split("\n")
    assert_match HEADER, lines[0]
    lines[1..-1]
  end

  # Runs the block and puts the sections, their groups and the registered blocks back as they were.
  def kept_sections
    all = Keys::DIAG_ALL.dup
    groups = Keys::DIAG_SECTIONS.map { |g, list| [g, list.dup] }
    extras = (Keys.instance_variable_get(:@extra_diags) || {}).dup
    yield
  ensure
    Keys::DIAG_ALL.replace(all)
    groups.each { |g, list| Keys::DIAG_SECTIONS[g].replace(list) }
    Keys.instance_variable_set(:@extra_diags, extras)
  end

  # Runs the block with the engine's capability registry holding only caps, the shipped one put back after.
  def with_capabilities(caps)
    registry = PokeAccess::Engine::CAPABILITIES
    saved = registry.dup
    registry.replace(caps)
    yield
  ensure
    registry.replace(saved)
  end

  # Runs the block with $player and $Trainer as given and the gen-6 battle scene class defined or not, all put back
  # after.
  def with_engine_globals(player, trainer, battle_scene)
    saved = [$player, $Trainer]
    had = Object.const_defined?(:PokeBattle_Scene)
    was = had ? Object.send(:remove_const, :PokeBattle_Scene) : nil
    Object.const_set(:PokeBattle_Scene, Class.new) if battle_scene
    $player = player
    $Trainer = trainer
    yield
  ensure
    $player, $Trainer = saved
    Object.send(:remove_const, :PokeBattle_Scene) if Object.const_defined?(:PokeBattle_Scene)
    Object.const_set(:PokeBattle_Scene, was) if had
  end
end
