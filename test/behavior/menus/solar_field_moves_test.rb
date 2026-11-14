class SolarFieldMovesTest < PokeAccessTest
  ITEMS = { :CUT => :CLIPPERS, :ROCKSMASH => :HAMMER, :STRENGTH => :STRENGTHGLOVES,
            :SURF => :SURFBOARD, :DIVE => :SNORKLE, :WATERFALL => :BOARDMOTOR }

  test "each Solar tool enables its own field action without a badge or Pokemon, and no unrelated one" do
    with_solar do |moves, state|
      ITEMS.each do |move, item|
        state[2] = []
        assert_equal false, moves.can?(move), "nothing available for #{move}"
        state[2] = [item]
        ITEMS.each_key { |other| assert_equal other == move, moves.can?(other), "#{item} for #{other}" }
      end
    end
  end

  test "without Solar's tools normal moves require knowledge and badge, with Strength using its badge alone" do
    with_solar do |moves, state|
      [[true, false, false], [false, true, false], [true, true, true]].each do |knows, badge, want|
        state[0], state[1] = knows, badge
        ITEMS.each_key { |move| assert_equal (move == :STRENGTH ? badge : want), moves.can?(move), "#{move}: knows #{knows}, badge #{badge}" }
      end
    end
  end

  test "Solar permits its following Pokemon to surf but blocks another dependent companion" do
    with_solar do |_moves, _state|
      with_const(:Following_Activated_Switch, 981) do
        was = $game_player
        previous = $game_switches[981]
        begin
          $game_player = Object.new
          $game_player.define_singleton_method(:pbHasDependentEvents?) { true }
          $game_switches[981] = false
          assert_equal false, PokeAccess::Pathfinder.surf_with_company?
          $game_switches[981] = true
          assert_equal true, PokeAccess::Pathfinder.surf_with_company?
        ensure
          $game_player = was
          $game_switches[981] = previous
        end
      end
    end
  end

  private

  # Gives the follower rule a real switch constant and restores any prior definition.
  def with_const(name, value)
    present = Object.const_defined?(name)
    before = Object.const_get(name) if present
    Object.send(:remove_const, name) if present
    Object.const_set(name, value)
    yield
  ensure
    Object.send(:remove_const, name)
    Object.const_set(name, before) if present
  end

  # Isolates the declared items and party/badge/bag capabilities from other profiles' rules.
  def with_solar
    moves = PokeAccess::FieldMoves
    keep = [:can?, :knows?, :badge_ok?].map { |name| [name, moves.method(name)] }
    items, tools = moves.instance_variable_get(:@items), moves.instance_variable_get(:@tools)
    profiles = PokeAccess::Game.profiles.dup
    profile_name = PokeAccess::Game.instance_variable_get(:@profile_name)
    company = PokeAccess::Pathfinder.instance_variable_get(:@surf_company)
    bag = $PokemonBag
    state = [false, false, []]
    moves.instance_variable_set(:@items, {})
    moves.instance_variable_set(:@tools, {})
    moves.define_singleton_method(:knows?) { |_move| state[0] }
    moves.define_singleton_method(:badge_ok?) { |_move| state[1] }
    $PokemonBag = Object.new
    $PokemonBag.define_singleton_method(:pbQuantity) { |item| state[2].include?(item) ? 1 : 0 }
    load File.join(Harness::ROOT, "games", "solar_light_lunar_dark", "constants.rb")
    yield moves, state
  ensure
    keep.each { |name, method| moves.define_singleton_method(name, method) }
    moves.instance_variable_set(:@items, items)
    moves.instance_variable_set(:@tools, tools)
    PokeAccess::Game.instance_variable_set(:@profiles, profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, profile_name)
    PokeAccess::Pathfinder.instance_variable_set(:@surf_company, company)
    $PokemonBag = bag
  end
end
