# Infinite Fusion's hat screen for a Pokemon (games/infinitefusion_common/hat_screen.rb), gamedata pass: picking the hat
# says it by name as it changes, placing it says where it sits, step by step, and when an arrow moves it no further.

# The presenter and its view are reduced to their loops' frames, each one a view update, as the game runs them; they
# are defined before the profile file binds to them.
class PokemonHatView
  def initialize(presenter); @presenter = presenter; end
  def update; nil; end
end

class PokemonHatPresenter
  def initialize(hat_id, x, y)
    @hat_id = hat_id
    @x_pos = x
    @y_pos = y
    @view = PokemonHatView.new(self)
  end

  # The pick's frames: the one it opens on, then one per hat the arrows bring.
  def select_hat(ids = [])
    @view.update
    ids.each { |i| @hat_id = i; @view.update }
    true
  end

  # The placement's frames: the one it opens on, then one per move of [dx, dy] pixels (0, 0 for a blocked press).
  def position_hat(moves = [])
    @view.update
    moves.each { |dx, dy| @x_pos += dx; @y_pos += dy; @view.update }
    true
  end
end

hat_screen = File.join(Harness::ROOT, "games", "infinitefusion_common", "hat_screen.rb")
eval(Harness.source(hat_screen), TOPLEVEL_BINDING, hat_screen)

class IfHatScreenGdTest < PokeAccessTest
  # The hats' names in the game's outfit data.
  HATS = { "cap" => "Gorra", "crown" => "Corona" }.freeze

  test "says the hat the pick opens on, then each new hat the arrows bring, interrupting" do
    with_hats { PokemonHatPresenter.new("cap", 0, 0).select_hat(["cap", "crown"]) }
    assert_equal [[PokeAccess::I18n.t(:if_hat_pick, :name => "Gorra"), true], ["Corona", true]], SpeakCapture.log
  end

  test "names a hat by the outfit data, or by its id where the data names nothing" do
    names = with_hats { ["cap", "nameless", "unknown"].map { |id| PokeAccess::IFHatScreen.hat_name(id) } }
    assert_equal ["Gorra", "nameless", "unknown"], names
  end

  test "opens each pick whole, on the hat worn" do
    pres = PokemonHatPresenter.new("cap", 0, 0)
    with_hats { 2.times { pres.select_hat } }
    assert_equal [PokeAccess::I18n.t(:if_hat_pick, :name => "Gorra")] * 2, SpeakCapture.lines
  end

  test "says where the placement opens, then each step from the picture's corner" do
    PokemonHatPresenter.new("cap", 0, 0).position_hat([[4, 0], [4, 8]])
    assert_equal [[place(t(:if_hat_corner)), true], [from_corner(1, 0), true], [from_corner(2, 2), true]], SpeakCapture.log
  end

  test "counts where the hat sits in whole steps from the corner, in every direction" do
    { [0, 0] => t(:if_hat_corner), [4, 0] => from_corner(1, 0), [8, 8] => from_corner(2, 2),
      [-8, 4] => from_corner(-2, 1), [0, -4] => from_corner(0, -1) }.each do |(x, y), said|
      assert_equal said, PokeAccess::IFHatScreen.where(PokemonHatPresenter.new("cap", x, y)), "at (#{x}, #{y})"
    end
  end

  test "says the edge when an arrow moves the hat no further" do
    pressing(Input::RIGHT) { PokemonHatPresenter.new("cap", 8, 8).position_hat([[0, 0]]) }
    assert_equal [[place(from_corner(2, 2)), true], [t(:if_hat_edge), true]], SpeakCapture.log
  end

  test "says no edge on a frame with no arrow pressed, or an input that cannot be read" do
    PokemonHatPresenter.new("cap", 8, 8).position_hat([[0, 0]])
    raising = lambda { |*_a| raise ArgumentError, "no input" }
    with_trigger(raising) { PokemonHatPresenter.new("cap", 8, 8).position_hat([[0, 0]]) }
    assert_equal [place(from_corner(2, 2))] * 2, SpeakCapture.lines
  end

  test "says nothing for the view's frames outside both steps" do
    pres = PokemonHatPresenter.new("cap", 0, 0)
    pres.select_hat
    pres.position_hat
    SpeakCapture.clear
    pres.instance_variable_set(:@hat_id, "crown")
    pres.instance_variable_set(:@x_pos, 4)
    PokemonHatView.new(pres).update
    assert_nothing_spoken
  end

  private

  def t(key)
    PokeAccess::I18n.t(key)
  end

  # The placement's opening line, where being where the hat sits.
  def place(where)
    PokeAccess::I18n.t(:if_hat_place, :where => where)
  end

  # Where the hat sits as said, dx and dy whole steps from the corner.
  def from_corner(dx, dy)
    PokeAccess::I18n.t(:if_hat_from_corner, :where => PokeAccess::Locator.dir_phrase(dx, dy))
  end

  # The block's value with the game's get_hat_by_id answering HATS, an empty name for "nameless" and raising for an
  # id it does not have.
  def with_hats
    hat = Struct.new(:name)
    lookup = lambda do |id|
      raise ArgumentError, "no hat #{id}" unless HATS.key?(id) || id == "nameless"
      hat.new(HATS[id].to_s)
    end
    GameFunctions.with(:get_hat_by_id => lookup) { yield }
  end

  # The block's value with only key reported as triggered this frame.
  def pressing(key)
    with_trigger(lambda { |k| k == key }) { yield }
  end

  # The block's value with Input.trigger? answering through fn, put back afterwards.
  def with_trigger(fn)
    trig = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?, &fn)
    yield
  ensure
    Input.define_singleton_method(:trigger?, trig)
  end
end
