# Util.dex_seen? and dex_owned? answer from the first Pokedex source that answers (the player's predicates, its
# pokedex's, gen-6's arrays, the data provider's species row), or nil, meaning unknown, when none does.
class DexFlagsTest < PokeAccessTest
  Util = PokeAccess::Util

  # Gen-6's trainer: seen and owned arrays indexed by species.
  class ArraysTrainer
    attr_reader :seen, :owned
    def initialize(seen, owned); @seen = seen; @owned = owned; end
  end

  # A v18 player or a v19+ pokedex: seen? and owned? over lists of species.
  class Predicates
    def initialize(seen, owned); @seen = seen; @owned = owned; end
    def seen?(sp); @seen.include?(sp); end
    def owned?(sp); @owned.include?(sp); end
  end

  # A v19+ player, whose flags live on its pokedex.
  class NestedTrainer
    attr_reader :pokedex
    def initialize(dex); @pokedex = dex; end
  end

  # A data provider keeping a Pokedex row per species, as the Reborn engine's does.
  class RowProvider
    def initialize(rows); @rows = rows; end
    def dex_row(sp); @rows[sp]; end
  end

  test "reads gen-6's seen and owned arrays" do
    as_player(ArraysTrainer.new(indexed(25), indexed)) do
      assert_equal [true, false, false], [Util.dex_seen?(25), Util.dex_seen?(4), Util.dex_owned?(25)]
    end
  end

  test "reads the player's seen? and owned? predicates" do
    as_player(Predicates.new([25, 4], [25])) do
      assert_equal [true, true, false], [Util.dex_seen?(4), Util.dex_owned?(25), Util.dex_owned?(4)]
    end
  end

  test "reads the predicates of the player's pokedex" do
    as_player(NestedTrainer.new(Predicates.new([151], [151]))) do
      assert_equal [true, true, false], [Util.dex_seen?(151), Util.dex_owned?(151), Util.dex_seen?(1)]
    end
  end

  test "answers a predicate's truthy value as true" do
    as_player(Class.new { def seen?(_sp); 1; end }.new) { assert_equal true, Util.dex_seen?(25) }
  end

  test "passes over a predicate that answers nil or raises to the next source" do
    nil_pred = Class.new(ArraysTrainer) { def seen?(_sp); nil; end }
    raising = Class.new(NestedTrainer) { def seen?(_sp); raise "no dex yet"; end }
    as_player(nil_pred.new(indexed(25), indexed)) { assert_equal true, Util.dex_seen?(25), "nil passes to the arrays" }
    as_player(raising.new(Predicates.new([25], []))) do
      assert_equal true, Util.dex_seen?(25), "a raise passes to the pokedex"
    end
  end

  test "reads the provider's species row when the player keeps no Pokedex" do
    rows = { 25 => { :seen? => true, :owned? => false }, 4 => { :seen? => nil } }
    Harness.with_provider(RowProvider.new(rows)) do
      as_player(Object.new) do
        assert_equal [true, false, false], [Util.dex_seen?(25), Util.dex_owned?(25), Util.dex_seen?(4)]
        assert_nil Util.dex_seen?(1), "a species with no row is unknown"
      end
    end
  end

  test "passes over a pokedex whose predicate answers nil to the player's arrays" do
    player = Class.new(ArraysTrainer) { def pokedex; Class.new { def seen?(_sp); nil; end }.new; end }
    as_player(player.new(indexed(25), indexed)) { assert_equal true, Util.dex_seen?(25) }
  end

  test "is unknown with no player, a player without a Pokedex, or no species" do
    as_player(nil) { assert_nil Util.dex_seen?(25), "no player" }
    as_player(Object.new) { assert_nil Util.dex_owned?(25), "a player answering none of the ways" }
    as_player(Predicates.new([25], [25])) { assert_nil Util.dex_seen?(nil), "no species" }
  end

  test "is unknown when the player's flag list cannot be read" do
    unreadable = Class.new { def seen; Object.new; end }
    as_player(unreadable.new) { assert_nil Util.dex_seen?(25) }
  end

  private

  # Runs the block with the engine's player being who: $player as GameData does, $Trainer cleared (nil clears both);
  # both come back after.
  def as_player(who)
    saved = [$player, $Trainer]
    $player = who
    $Trainer = nil
    yield
  ensure
    $player, $Trainer = saved
  end

  # A gen-6 flag array: true at each species given, nothing elsewhere.
  def indexed(*species)
    species.each_with_object([]) { |sp, a| a[sp] = true }
  end
end
