# Soulstones' edit of FL's HMs as Items (games/soulstones1/field_moves.rb): a PokeGear app in the bag stands in for each
# of six field moves with no Pokemon that knows it, once that move's badge is won.
class Soulstones1FieldMovesTest < PokeAccessTest
  FM = PokeAccess::FieldMoves
  PROFILE = File.join(Harness::ROOT, "games", "soulstones1", "field_moves.rb")
  # The badge each move needs, as gen-6 games number them: Cut's is the second, Surf's the fourth.
  BADGES = { "BADGEFORCUT" => 1, "BADGEFORSURF" => 3 }
  # What the profile file registered, from its one evaluation in this process (see with_profile).
  LOADED = []

  test "each app in the bag stands in for its own move" do
    apps = { :CUT => :CUTITEM, :ROCKSMASH => :ROCKSMAMUKEM, :STRENGTH => :STRENGTHITEM, :SURF => :SURFITEM,
             :DIVE => :DIVEITEM, :WATERFALL => :WATERFALLITEM }
    with_profile do
      apps.each { |move, app| assert_equal true, in_world([app], 8) { FM.can?(move) }, "#{app} for #{move}" }
    end
  end

  test "an app stands in for no other move" do
    with_profile { assert_equal false, in_world([:CUTITEM], 8) { FM.can?(:SURF) } }
  end

  test "an app stands in for its move only once the move's badge is won" do
    with_profile do
      assert_equal({ :CUT => true, :SURF => false },
                   in_world([:CUTITEM, :SURFITEM], 2) { { :CUT => FM.can?(:CUT), :SURF => FM.can?(:SURF) } },
                   "with two badges Cut's is won and Surf's is not")
    end
  end

  test "with neither the app nor a Pokemon that knows it there is no move" do
    with_profile { assert_equal false, in_world([], 8) { FM.can?(:CUT) } }
  end

  test "without the profile an app is nothing to the core" do
    assert_equal false, in_world([:CUTITEM], 8) { FM.can?(:CUT) }
  end

  private

  # The block's value with a bag holding items, no party Pokemon that knows any move and the first badges won, the
  # game's badge constants defined; all put back afterwards.
  def in_world(items, badges)
    bag_was = $PokemonBag
    badges_was = $Trainer.badges
    knows = FM.method(:knows?)
    made = BADGES.keys.reject { |c| Object.const_defined?(c) }
    made.each { |c| Object.const_set(c, BADGES[c]) }
    $PokemonBag = Object.new
    $PokemonBag.define_singleton_method(:pbQuantity) { |id| items.include?(id) ? 1 : 0 }
    $Trainer.badges = [true] * badges + [false] * (8 - badges)
    FM.define_singleton_method(:knows?) { |_m| false }
    yield
  ensure
    $PokemonBag = bag_was
    $Trainer.badges = badges_was
    FM.define_singleton_method(:knows?, knows)
    made.each { |c| Object.send(:remove_const, c) }
  end

  # Runs the block with what the profile file registers in force (the apps, its override of FieldMoves.item_ready?, its
  # profile name and its module), taken out again afterwards. The file is evaluated once per process, as the loader
  # evaluates it, and what it registered is kept for the next test.
  def with_profile
    added = (LOADED[0] ||= loaded)
    saved = registries
    install(added)
    yield
  ensure
    restore(saved) if saved
  end

  # Evaluates the profile file and answers what it registered, everything it registered taken out again.
  def loaded
    before = registries
    eval(Harness.source(PROFILE), TOPLEVEL_BINDING, PROFILE)
    now = registries
    meta = FM.singleton_class
    added = { :items => now[:items].map { |move, list| [move, list - (before[:items][move] || [])] },
              :profiles => now[:profiles][0] - before[:profiles][0],
              :overrides => now[:overrides] - before[:overrides],
              :consts => (now[:consts] - before[:consts]).map { |c| [c, PokeAccess.const_get(c)] },
              :ready => now[:ready],
              :aliases => (now[:own] - before[:own]).map { |a| [a, meta.instance_method(a)] } }
    restore(before)
    added
  end

  # The registries the profile adds to, as they stand: the field-move items, the profile names, the overrides listed,
  # the toolkit's constants, FieldMoves.item_ready? and the names of FieldMoves' own module methods.
  def registries
    game = PokeAccess::Game
    meta = FM.singleton_class
    { :items => Hash[FM.instance_variable_get(:@items).map { |move, list| [move, list.dup] }],
      :profiles => [game.profiles.dup, game.instance_variable_get(:@profile_name)],
      :overrides => PokeAccess::Hooks.overrides.dup,
      :consts => PokeAccess.constants,
      :ready => meta.instance_method(:item_ready?),
      :own => meta.instance_methods(false) }
  end

  # Puts what the profile registered (loaded) in force.
  def install(added)
    added[:items].each { |move, list| list.each { |it| FM.register_item(move, it) } }
    PokeAccess::Game.profiles.concat(added[:profiles])
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
    PokeAccess::Hooks.overrides.concat(added[:overrides])
    added[:consts].each { |c, v| PokeAccess.const_set(c, v) }
    meta = FM.singleton_class
    added[:aliases].each { |a, um| meta.send(:define_method, a, um) }
    meta.send(:define_method, :item_ready?, added[:ready])
  end

  # Puts the registries back as registries took them.
  def restore(saved)
    FM.instance_variable_set(:@items, saved[:items])
    PokeAccess::Game.profiles.replace(saved[:profiles][0])
    PokeAccess::Game.instance_variable_set(:@profile_name, saved[:profiles][1])
    PokeAccess::Hooks.overrides.replace(saved[:overrides])
    (PokeAccess.constants - saved[:consts]).each { |c| PokeAccess.send(:remove_const, c) }
    meta = FM.singleton_class
    meta.send(:define_method, :item_ready?, saved[:ready])
    (meta.instance_methods(false) - saved[:own]).each { |a| meta.send(:remove_method, a) }
  end
end
