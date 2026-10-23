# Grueling Gold's egg move tutor (games/gruelinggold/egg_relearner.rb): a renamed copy of the stock relearner, read
# through core's relearner pieces: the focused move's detail on each redraw of the list, and the prompts its screen
# writes, said before they show.

# The tutor's scene as the hooks see it, defined once at file level (hooks bind once per "Class#method").
class EggRelearner_Scene
  def pbStartScene(_pokemon, _moves); :started; end
  def pbDrawMoveList; :drawn; end
  def pbDisplay(_msg); :shown; end
end

class GruelingGoldEggRelearnerTest < PokeAccessTest
  PROFILE_FILE = File.join(Harness::ROOT, "games", "gruelinggold", "egg_relearner.rb")

  test "each redraw of the move list reads the focused move's detail, and the scene answers its own value" do
    calls = spy(PokeAccess::MoveList, :detail) { assert_equal :drawn, EggRelearner_Scene.new.pbDrawMoveList }
    assert_equal 1, calls.length
  end

  test "a prompt the tutor writes on its help window is said before it shows" do
    calls = spy(PokeAccess, :say_screen_message) { EggRelearner_Scene.new.pbDisplay("Teach which move?") }
    assert_equal [[["Teach which move?"]]], calls
  end

  private

  # Runs the block with mod.name recorded instead of run, after binding the profile file once; returns the calls.
  def spy(mod, name)
    self.class.bind_profile
    calls = []
    saved = mod.method(name)
    mod.define_singleton_method(name) { |*args| calls.push(args) }
    yield
    calls
  ensure
    mod.define_singleton_method(name, saved) if saved
  end

  # Evaluates the profile file once per process, as the loader does.
  def self.bind_profile
    return if @bound
    @bound = true
    eval(Harness.source(PROFILE_FILE), TOPLEVEL_BINDING, PROFILE_FILE)
  end
end
