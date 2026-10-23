# Whether the player can use a field move now (FieldMoves.can?), as the game decides: a Pokemon that knows it, an item
# standing in for it, the badge it needs; a party that cannot be read gives nil, never a no.
class FieldMovesTest < PokeAccessTest
  FM = PokeAccess::FieldMoves

  test "a party the engine cannot search answers nothing, not no" do
    assert_nil FM.can?(:DIVE)
  end

  test "with no trainer the party cannot be read" do
    with_trainer(nil) { assert_nil FM.can?(:DIVE) }
  end

  test "the engine's finder decides: a Pokemon that knows the move can use it, and with none nobody can" do
    { :pk => true, nil => false }.each do |found, want|
      with_finder(found) { assert_equal want, FM.can?(:DIVE), "with the finder answering #{found.inspect}" }
    end
  end

  test "a gen-6 party is searched with pbCheckMove" do
    { :pk => true, nil => false }.each do |found, want|
      with_kernel_method(:pbCheckMove, lambda { |_move| found }) do
        assert_equal want, FM.can?(:CUT), "with pbCheckMove answering #{found.inspect}"
      end
    end
  end

  test "a Pokemon that could only learn the move cannot use it where the game does not say it may" do
    with_finder(nil, :pk) { assert_equal false, FM.can?(:CUT) }
  end

  test "where the game lets a Pokemon use a move it could learn, one that can learn it counts" do
    with_finder(nil, :pk) do
      with_settings(:USE_HM_WITHOUT_LEARNING_THEM => true) { assert_equal true, FM.can?(:CUT), "one could learn it" }
      with_settings(:USE_HM_WITHOUT_LEARNING_THEM => false) { assert_equal false, FM.can?(:CUT), "the game says no" }
    end
    with_finder(nil, nil) do
      with_settings(:USE_HM_WITHOUT_LEARNING_THEM => true) { assert_equal false, FM.can?(:CUT), "and none could" }
    end
  end

  test "an item a game registered for the move stands in for the party while it is in the bag" do
    with_finder(nil) do
      with_registered_item(:DIVE, :SPECGEAR) do
        with_bag([:SPECGEAR]) { assert_equal true, FM.can?(:DIVE), "the gear in the bag" }
        with_bag([:POTION]) { assert_equal false, FM.can?(:DIVE), "and without it, no" }
      end
    end
  end

  test "with Marin's HM Items switched on for a move, its item is the whole rule" do
    with_constants(:USING_SURF_ITEM => true, :SURF_ITEM => :SPECSURFITEM) do
      with_finder(:pk) do
        with_bag([]) { assert_equal false, FM.can?(:SURF), "knowing Surf is not enough once the item has taken it over" }
      end
      with_finder(nil) do
        with_bag([:SPECSURFITEM]) { assert_equal true, FM.can?(:SURF), "and the item is, though nobody knows it" }
      end
    end
  end

  test "with Marin's HM Items switched off, or naming no item, the party decides" do
    with_finder(:pk) do
      with_bag([]) do
        with_constants(:USING_SURF_ITEM => false, :SURF_ITEM => :SPECSURFITEM) { assert_equal true, FM.can?(:SURF) }
        with_constants(:USING_DIVE_ITEM => true) { assert_equal true, FM.can?(:DIVE) }
      end
    end
  end

  test "Marin's HM Items spell Rock Smash ROCK_SMASH" do
    with_constants(:USING_ROCK_SMASH_ITEM => true, :ROCK_SMASH_ITEM => :SMASHITEM) do
      with_finder(:pk) do
        with_bag([]) { assert_equal false, FM.can?(:ROCKSMASH), "the item has taken the move over" }
        with_bag([:SMASHITEM]) { assert_equal true, FM.can?(:ROCKSMASH) }
      end
    end
  end

  test "the Advanced Items plugin's item is asked through its own predicate" do
    asked = []
    with_advanced_items(:CUT_CONFIG => { :internal_name => :CUTITEM, :item => true }) do
      with_finder(nil) do
        with_private_method(:pbCanUseItem, lambda { |cfg| asked.push(cfg[:internal_name]); true }) do
          assert_equal true, FM.can?(:CUT), "the plugin says the item may be used"
        end
        with_private_method(:pbCanUseItem, lambda { |cfg| asked.push(cfg[:internal_name]); false }) do
          assert_equal false, FM.can?(:CUT), "and when it says no, the party decides"
        end
      end
    end
    assert_equal [:CUTITEM, :CUTITEM], asked
  end

  test "an Advanced Items predicate that fails is no stand-in" do
    with_advanced_items(:CUT_CONFIG => { :internal_name => :CUTITEM, :item => true }) do
      with_finder(nil) do
        with_private_method(:pbCanUseItem, lambda { |_cfg| raise "broken" }) { assert_equal false, FM.can?(:CUT) }
      end
    end
  end

  test "the Advanced Items plugin is not asked for a move it gives no item to, nor for one it does not know" do
    asked = []
    with_advanced_items(:CUT_CONFIG => { :internal_name => :CUTITEM, :item => false }, :FLY_CONFIG => "not a config") do
      with_finder(:pk) do
        with_private_method(:pbCanUseItem, lambda { |cfg| asked.push(cfg); true }) do
          assert_equal [true, true, true], [FM.can?(:CUT), FM.can?(:FLY), FM.can?(:SURF)], "the party decides"
        end
      end
    end
    assert_equal [], asked
  end

  test "the gen-6 badge a move needs is BADGEFOR<MOVE>, by its index among the badges" do
    with_finder(:pk) do
      {
        [3, [false, false, false, true]] => true,
        [3, [true, true, true, false]] => false,
        [0, [false, true]] => false,
        [0, [true, false]] => true,
        [-1, [false]] => true
      }.each do |(badge, won), want|
        with_constants(:BADGEFORSTRENGTH => badge) do
          with_badges(won) { assert_equal want, FM.can?(:STRENGTH), "badge #{badge} with #{won.inspect} won" }
        end
      end
    end
  end

  test "a game that counts badges needs that many, whichever they are" do
    with_finder(:pk) do
      with_constants(:BADGEFORSTRENGTH => 3, :HIDDENMOVESCOUNTBADGES => true) do
        { [true, true, true, false] => true, [false, true, false, true, true] => true, [true, false, true] => false }
          .each { |won, want| with_badges(won) { assert_equal want, FM.can?(:STRENGTH), "with #{won.inspect} won" } }
      end
    end
  end

  test "from v19 the badge a move needs is Settings::BADGE_FOR_<MOVE>" do
    with_finder(:pk) do
      with_settings(:BADGE_FOR_SURF => 2) do
        with_badges([false, false, true]) { assert_equal true, FM.can?(:SURF) }
        with_badges([true, true, false]) { assert_equal false, FM.can?(:SURF) }
      end
    end
  end

  test "the engine's own badge check is asked where it has one, showing no message" do
    asked = []
    with_finder(:pk) do
      with_constants(:BADGEFORSTRENGTH => 3) do
        with_private_method(:pbCheckHiddenMoveBadge, lambda { |badge, show| asked.push([badge, show]); badge == 3 }) do
          with_badges([false]) { assert_equal true, FM.can?(:STRENGTH), "it says the badge is won" }
        end
        with_private_method(:pbCheckHiddenMoveBadge, lambda { |badge, show| asked.push([badge, show]); false }) do
          with_badges([true, true, true, true]) { assert_equal false, FM.can?(:STRENGTH), "it says it is not" }
        end
      end
    end
    assert_equal [[3, false], [3, false]], asked
  end

  test "a move the game names no badge for needs none" do
    with_finder(:pk) { with_badges([false] * 8) { assert_equal true, FM.can?(:FLASH) } }
  end

  test "badges the engine cannot read, or no trainer to read them from, do not keep the move from use" do
    with_constants(:BADGEFORSTRENGTH => 3) do
      broken = Object.new
      def broken.badges; raise "unreadable"; end
      with_trainer(broken) { assert_equal true, FM.badge_ok?(:STRENGTH), "unreadable badges" }
      with_trainer(nil) { assert_equal true, FM.badge_ok?(:STRENGTH), "no trainer" }
    end
  end

  test "a move is said by the name the game gives it, else by its own" do
    provider = Object.new
    def provider.move_id(sym); sym == :SURF ? 57 : 0; end
    def provider.move_name(id); id == 57 ? "Surf" : ""; end
    Harness.with_provider(provider) do
      assert_equal ["Surf", "Rocksmash"], [FM.name(:SURF), FM.name(:ROCKSMASH)]
    end
  end

  # The boot profile's tools (Pokemon Z rides Surf on its mount alone), which Reset puts back before every test, set
  # aside, so each test sees the core's rules.
  def setup
    super
    FM.instance_variable_set(:@tools, {})
  end

  private

  # Runs the block with the v19 finders on the trainer: get_pokemon_with_move answering found and, when learner is
  # given, get_pokemon_can_learn_move answering it.
  def with_finder(found, learner = :none)
    tr = PokeAccess::Engine.player
    tr.define_singleton_method(:get_pokemon_with_move) { |_m| found }
    tr.define_singleton_method(:get_pokemon_can_learn_move) { |_m| learner } unless learner == :none
    yield
  ensure
    [:get_pokemon_with_move, :get_pokemon_can_learn_move].each do |m|
      tr.singleton_class.send(:remove_method, m) if tr.singleton_methods.include?(m)
    end
  end

  # Runs the block with a gen-6 bag holding one of each of items, and no modern one.
  def with_bag(items)
    had = [$bag, $PokemonBag]
    bag = Object.new
    bag.define_singleton_method(:pbQuantity) { |item| items.include?(item) ? 1 : 0 }
    $bag = nil
    $PokemonBag = bag
    yield
  ensure
    $bag, $PokemonBag = had
  end

  # Runs the block with the trainer's badges set to won (one flag per badge).
  def with_badges(won)
    tr = PokeAccess::Engine.player
    had = tr.badges
    tr.badges = won
    yield
  ensure
    tr.badges = had
  end

  # Runs the block with $Trainer set to trainer (nil for none).
  def with_trainer(trainer)
    had = $Trainer
    $Trainer = trainer
    yield
  ensure
    $Trainer = had
  end

  # Runs the block with item registered for move, putting back the items registered before.
  def with_registered_item(move, item)
    items = FM.instance_variable_get(:@items)
    had = items[move] && items[move].dup
    FM.register_item(move, item)
    yield
  ensure
    had ? items[move] = had : items.delete(move)
  end

  # Runs the block with top-level constants set (a game's), each removed or put back after.
  def with_constants(values)
    had = {}
    values.each do |name, v|
      had[name] = Object.const_get(name) if Object.const_defined?(name, false)
      Object.send(:remove_const, name) if Object.const_defined?(name, false)
      Object.const_set(name, v)
    end
    yield
  ensure
    values.each_key do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name, false)
      Object.const_set(name, had[name]) if had.key?(name)
    end
  end

  # Runs the block with a Settings module (v19) holding values, removed after.
  def with_settings(values)
    mod = Module.new
    values.each { |name, v| mod.const_set(name, v) }
    with_constants(:Settings => mod) { yield }
  end

  # Runs the block with the Advanced Items plugin's module holding configs.
  def with_advanced_items(configs)
    mod = Module.new
    configs.each { |name, v| mod.const_set(name, v) }
    with_constants(:AdvancedItemsFieldMoves => mod) { yield }
  end

  # Runs the block with a private method of every object (a game's global function) answered by body.
  def with_private_method(name, body)
    Object.send(:define_method, name, &body)
    Object.send(:private, name)
    yield
  ensure
    Object.send(:remove_method, name)
  end

  # Runs the block with a Kernel module function (gen-6's def Kernel.x) answered by body.
  def with_kernel_method(name, body)
    Kernel.define_singleton_method(name, &body)
    yield
  ensure
    Kernel.singleton_class.send(:remove_method, name)
  end
end
