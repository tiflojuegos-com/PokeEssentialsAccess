# The summary header's icons in its order: the ball, one status slot (fainted, else a status, else catching pokerus),
# the cured-pokerus mark, the shiny star and the marks set; nothing when the header draws none.
class SummaryHeaderIconsTest < PokeAccessTest
  T = PokeAccess::I18n
  S = PokeAccess::Summary
  # A gen-6 Pokemon as the header asks it.
  Mon = Struct.new(:hp, :status, :pokerusStage, :ballused, :shiny, :markings) do
    def isShiny?; shiny; end
  end
  # An engine's data whose items all have a blank name.
  NamelessItems = Class.new { def item_name(_id); ""; end }

  test "says the ball, the cured-pokerus mark and the shiny star, in the header's order" do
    with_ball_function do
      assert_equal [T.t(:sum_ball, :b => "Pocion"), T.t(:pk_pokerus_cured), T.t(:pk_shiny)].join(", "),
                   S.header_icons(Mon.new(20, 0, 2, 1, true))
    end
  end

  test "the status slot says fainted before a status" do
    assert_equal T.t(:pk_fainted), S.header_icons(Mon.new(0, 1, 1, nil, false))
  end

  test "the status slot says a status before pokerus" do
    assert_equal T.t(:st_sleep), S.header_icons(Mon.new(5, 1, 1, nil, false))
  end

  test "the status slot says pokerus that is catching when it is free" do
    assert_equal T.t(:pk_pokerus), S.header_icons(Mon.new(5, 0, 1, nil, false))
  end

  test "a header that draws nothing says nothing" do
    { "one hit point left" => Mon.new(1, 0, 0, nil, false), "a modern status of none" => Mon.new(20, :NONE, 0, nil, false),
      "hit points that cannot be read" => Struct.new(:status).new(0) }.each do |what, pk|
      assert_equal "", S.header_icons(pk), what
    end
  end

  test "the marks set on the Pokemon close the header" do
    names = [T.t(:mk_circle), T.t(:mk_square)].join(", ")
    assert_equal [T.t(:pk_shiny), T.t(:mk_list, :list => names)].join(", "),
                 S.header_icons(Mon.new(20, 0, 0, nil, true, [1, 0, 1]))
  end

  test "a ball number the game turns into no item is no ball" do
    with_ball_function { assert_nil S.ball_name(Mon.new(5, 0, 0, 7, false)) }
  end

  test "with no ball function in the game, a ball number is no ball" do
    without_ball_function { assert_nil S.ball_name(Mon.new(5, 0, 0, 1, false)) }
  end

  test "a ball kept as an item's id is that item" do
    without_ball_function { assert_equal "ItemPOTION", S.ball_name(Mon.new(5, 0, 0, :POTION, false)) }
  end

  test "a modern Pokemon's own ball is named as its item" do
    assert_equal "Pocion", S.ball_name(Struct.new(:poke_ball).new(PBItems::POTION))
  end

  test "a ball whose item the data names blank is no ball" do
    Harness.with_provider(NamelessItems.new, 30) { assert_nil S.ball_name(Struct.new(:poke_ball).new(PBItems::POTION)) }
  end

  private

  # Runs the block with the game's pbBallTypeToBall turning ball number 1 into a Potion and any other into nothing,
  # the game's own (or none) put back after.
  def with_ball_function
    swap_ball_function(lambda { |n| n == 1 ? PBItems::POTION : nil }) { yield }
  end

  # Runs the block with no pbBallTypeToBall, the game's own put back after.
  def without_ball_function
    swap_ball_function(nil) { yield }
  end

  # Runs the block with pbBallTypeToBall answering impl, or absent for nil, the game's own (or none) put back after.
  def swap_ball_function(impl)
    had = Object.private_method_defined?(:pbBallTypeToBall) || Object.method_defined?(:pbBallTypeToBall)
    Object.send(:alias_method, :pa_spec_ball_type, :pbBallTypeToBall) if had
    Object.send(:remove_method, :pbBallTypeToBall) if had
    Object.send(:define_method, :pbBallTypeToBall, &impl) if impl
    yield
  ensure
    Object.send(:remove_method, :pbBallTypeToBall) if impl
    if had
      Object.send(:alias_method, :pbBallTypeToBall, :pa_spec_ball_type)
      Object.send(:remove_method, :pa_spec_ball_type)
    end
  end
end
