# Rejuvenation's move relearner (games/rejuvenation/move_relearner.rb, over core's MoveRelearnerGen6): the page's label
# it paints above the list after the Pokemon's line, said again on a page change, and a page with no moves said by the
# message it paints in the description's place.
class RejuvenationRelearnerTest < PokeAccessTest
  # The reader's methods the profile overrides.
  SWAPPED = [:pokemon_head, :detail]
  Relearner = PokeAccess::MoveRelearnerGen6

  class << self
    # The profile's overrides, kept aside by load_profile.
    attr_reader :profile_methods
  end

  # Evaluates the profile file once, as boot does; its overrides are kept aside and core's put back, so the other tests
  # of the process keep core's; with_profile puts them in for a test.
  def self.load_profile
    meta = Relearner.singleton_class
    core = SWAPPED.map { |m| [m, meta.instance_method(m)] }
    profiles = PokeAccess::Game.profiles.dup
    path = File.join(Harness::ROOT, "games", "rejuvenation", "move_relearner.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    @profile_methods = SWAPPED.map { |m| [m, meta.instance_method(m)] }
  ensure
    core.each { |m, f| meta.send(:define_method, m, f) }
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  test "the page's label follows the Pokemon's line, and a page change says it again" do
    scene = page([], "No moves available.", "TM & HM moves")
    with_profile do
      Relearner.detail(scene)
      scene.instance_variable_set(:@label, "Egg moves")
      Relearner.detail(scene)
    end
    assert_equal [["TM & HM moves. No moves available.", true], ["Egg moves. No moves available.", true]], SpeakCapture.log
  end

  test "a page with no moves says its painted message, once the Pokemon's line was said only the message" do
    scene = page([], "Cannot relearn moves here.", "Natural moves")
    with_profile do
      Relearner.detail(scene)
      Relearner.detail(scene)
    end
    assert_equal "Cannot relearn moves here.", SpeakCapture.log.last[0]
  end

  test "a page with moves is left to the move's own line" do
    with_profile { assert_nil Relearner.detail(page([33], nil, "Natural moves", -1)) }
    assert_nothing_spoken
  end

  private

  # A relearner page: its moves, its message, its label and the list's cursor.
  def page(moves, error, label, index = 0)
    list = Struct.new(:index).new(index)
    World.stub_scene(:@moves => moves, :@error => error, :@label => label, :@sprites => { "commands" => list },
                     :@pokemon => nil)
  end

  # Runs the block with the profile's overrides in, core's put back after.
  def with_profile
    meta = Relearner.singleton_class
    core = SWAPPED.map { |m| [m, meta.instance_method(m)] }
    self.class.profile_methods.each { |m, f| meta.send(:define_method, m, f) }
    yield
  ensure
    core.each { |m, f| meta.send(:define_method, m, f) }
  end
end
