# An incubator slot (core/field/incubator.rb): an egg says the steps written under it and the sentence painted beside
# the grid, or how close it is by the screens' bands where none is painted; a free slot is just free; the first read
# of the screen is queued, later moves interrupt, and Royal's level is said before the first slot.
class IncubatorStepsTest < PokeAccessTest
  # The core's header and Royal's override of it: the profile file is evaluated once, here, and the core's header put
  # straight back, since the override would reach every other test of this engine; Royal's tests put it in for a block.
  CORE_HEADER = PokeAccess::Incubator.method(:header)
  path = File.join(Harness::ROOT, "games", "royal_common", "incubator_level.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
  ROYAL_HEADER = PokeAccess::Incubator.method(:header)
  PokeAccess::Incubator.define_singleton_method(:header, CORE_HEADER)

  test "an egg's slot says its steps and the sentence painted beside the grid, its markup left out" do
    painted = "<c3=FFFFFF>El huevo está listo.</c3>"
    text = with_incubators([egg(1), nil]) { PokeAccess::Incubator.text(slot(0), painted) }
    assert_equal t(:hatch_slot_egg, :n => 1, :state => "#{t(:hatch_steps, :n => 1)}. El huevo está listo."), text
  end

  test "where nothing is painted, how close the egg is goes by the screens' bands" do
    { 1 => :hatch_soon, 1274 => :hatch_soon, 1275 => :hatch_close, 2549 => :hatch_close, 2550 => :hatch_notclose,
      10199 => :hatch_notclose, 10200 => :hatch_far }.each do |steps, band|
      text = with_incubators([egg(steps)]) { PokeAccess::Incubator.text(slot(0)) }
      assert_equal t(:hatch_slot_egg, :n => 1, :state => "#{t(:hatch_steps, :n => steps)}. #{t(band)}"), text,
                   "#{steps} steps"
    end
  end

  test "a modern egg's steps are its steps_to_hatch" do
    modern = egg(9999)
    modern.define_singleton_method(:steps_to_hatch) { 300 }
    text = with_incubators([modern]) { PokeAccess::Incubator.text(slot(0)) }
    assert_equal t(:hatch_slot_egg, :n => 1, :state => "#{t(:hatch_steps, :n => 300)}. #{t(:hatch_soon)}"), text
  end

  test "a free slot is just free" do
    text = with_incubators([egg(1), nil]) { PokeAccess::Incubator.text(slot(1), "Selecciona una incubadora.") }
    assert_equal t(:hatch_slot_empty, :n => 2), text
  end

  test "without the incubators' eggs to ask, a slot reads as free" do
    assert_equal t(:hatch_slot_empty, :n => 1), PokeAccess::Incubator.text(slot(0))
  end

  test "brief and medium say the slot and its steps, full how close it is as well" do
    rows = with_incubators([egg(1)]) { vb_levels { PokeAccess::Incubator.text(slot(0), "El huevo está listo.") } }
    steps = t(:hatch_slot_egg, :n => 1, :state => t(:hatch_steps, :n => 1))
    assert_equal [steps, steps, whole_slot], rows
  end

  test "the info key and Ctrl+T say an egg's slot whole, whatever the verbosity" do
    PokeAccess::Config.verbosity = :brief
    with_incubators([egg(1)]) { PokeAccess::Incubator.text(slot(0), "El huevo está listo.") }
    assert_equal [whole_slot, whole_slot], [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "the info key and Ctrl+T say a free slot too" do
    with_incubators([nil]) { PokeAccess::Incubator.text(slot(0)) }
    free = t(:hatch_slot_empty, :n => 1)
    assert_equal [free, free], [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "a screen with no cursor reads nothing" do
    text = with_incubators([egg(1)]) do
      PokeAccess::Incubator.announce(World.stub_scene)
      PokeAccess::Incubator.text(World.stub_scene)
    end
    assert_nil text
    assert_nothing_spoken
  end

  test "the slot is read after the screen's redraw: the first read queued, later moves interrupting" do
    with_incubators([egg(1), nil]) do
      scene = slot(0)
      redraw(scene, "El huevo está listo.")
      scene.instance_variable_set(:@index, 1)
      redraw(scene, "Selecciona una incubadora.")
    end
    assert_equal [[whole_slot, false], [t(:hatch_slot_empty, :n => 2), true]], SpeakCapture.log
  end

  test "a slot redrawn with the same egg is not read again, and an egg put into it is" do
    eggs = [nil]
    with_incubators(eggs) do
      scene = slot(0)
      redraw(scene, "")
      SpeakCapture.clear
      redraw(scene, "")
      assert_nothing_spoken "the same free slot"
      eggs[0] = egg(1)
      redraw(scene, "El huevo está listo.")
    end
    assert_equal [[whole_slot, true]], SpeakCapture.log, "the egg just put in"
  end

  test "an egg swapped for another in the slot is read again" do
    eggs = [egg(1)]
    with_incubators(eggs) do
      scene = slot(0)
      redraw(scene, "El huevo está listo.")
      SpeakCapture.clear
      eggs[0] = egg(1)
      redraw(scene, "El huevo está listo.")
    end
    assert_equal [[whole_slot, true]], SpeakCapture.log
  end

  test "Royal's upgraded incubator says its level before the first slot only" do
    with_royal_header do
      with_incubators([egg(1), nil], 2) do
        scene = slot(0)
        redraw(scene, "El huevo está listo.")
        scene.instance_variable_set(:@index, 1)
        redraw(scene, "")
      end
    end
    assert_equal [["#{t(:hatch_level, :n => 2)}. #{whole_slot}", false], [t(:hatch_slot_empty, :n => 2), true]],
                 SpeakCapture.log
  end

  test "Royal's incubator with no level to show starts with the slot" do
    with_royal_header do
      with_incubators([egg(1)]) { redraw(slot(0), "El huevo está listo.") }
    end
    assert_equal [[whole_slot, false]], SpeakCapture.log
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # A gen-6 egg with steps left to hatch.
  def egg(steps)
    pk = Poke.build(:name => "Huevo")
    pk.define_singleton_method(:eggsteps) { steps }
    pk
  end

  # The incubator screen with its cursor on a slot (0 the first).
  def slot(index)
    World.stub_scene(:@index => index)
  end

  # The first slot holding an egg one step from hatching, with the sentence the screen paints for it, said whole.
  def whole_slot
    t(:hatch_slot_egg, :n => 1, :state => "#{t(:hatch_steps, :n => 1)}. El huevo está listo.")
  end

  # The screen's redraw as the incubator plugins drive it: armed, the sentence beside the grid painted, then the slot
  # announced.
  def redraw(scene, sentence)
    PokeAccess::Incubator.arm
    drawFormattedTextEx(nil, 0, 10, 200, sentence) unless sentence.empty?
    PokeAccess::Incubator.announce(scene)
  end

  # The block's value with $PokemonGlobal holding the incubators' eggs, and Royal's incubator level when given, the
  # engine's own put back after.
  def with_incubators(eggs, level = nil)
    saved = $PokemonGlobal
    global = Object.new
    global.define_singleton_method(:eggs) { eggs }
    global.define_singleton_method(:version_incubadora) { level } if level
    $PokemonGlobal = global
    yield
  ensure
    $PokemonGlobal = saved
  end

  # Runs the block with Royal's profile reading the incubator's level as the screen's header, the core's put back after.
  def with_royal_header
    PokeAccess::Incubator.define_singleton_method(:header, ROYAL_HEADER)
    yield
  ensure
    PokeAccess::Incubator.define_singleton_method(:header, CORE_HEADER)
  end
end
