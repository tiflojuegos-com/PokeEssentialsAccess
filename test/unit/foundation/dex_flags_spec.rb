# Util.dex_seen?/dex_owned? decide how the Pokedex list announces each row. The engines disagree on the API:
# gen-6 exposes plain seen/owned arrays on the trainer, while v18+ (Infinite Fusion) replaced them with
# seen?/owned? predicates -- sometimes on the player, sometimes on a nested pokedex object. Reading only the
# arrays raised on v18 and left the whole dex list silent, so the probe tries the predicate first and the
# array last, and reports nil when neither resolves (so "unknown" is not confused with "not seen").

# Stand-ins for each engine's player shape.
class FakeGen6Trainer
  attr_reader :seen, :owned
  def initialize(seen, owned); @seen = seen; @owned = owned; end
end
class FakeV18Trainer
  def initialize(seen, owned); @seen = seen; @owned = owned; end
  def seen?(sp); @seen.include?(sp); end
  def owned?(sp); @owned.include?(sp); end
end
class FakeNestedDex
  def initialize(seen, owned); @seen = seen; @owned = owned; end
  def seen?(sp); @seen.include?(sp); end
  def owned?(sp); @owned.include?(sp); end
end
class FakeNestedTrainer
  def initialize(dex); @dex = dex; end
  def pokedex; @dex; end
end

# Swaps the engine's player for the duration of the block.
def with_player(obj)
  prev = PokeAccess::Engine.method(:player)
  PokeAccess::Engine.instance_eval { define_singleton_method(:player) { obj } }
  begin
    yield
  ensure
    PokeAccess::Engine.instance_eval { define_singleton_method(:player) { prev.call } }
  end
end

Suite.define("dex flags: gen-6 seen/owned arrays") do
  with_player(FakeGen6Trainer.new({ 25 => true }, {})) do
    truthy "a seen species reads as seen", PokeAccess::Util.dex_seen?(25)
    falsy "an unseen species does not", PokeAccess::Util.dex_seen?(4)
    falsy "a seen but uncaught species is not owned", PokeAccess::Util.dex_owned?(25)
  end
end

Suite.define("dex flags: v18 seen?/owned? predicates on the player") do
  with_player(FakeV18Trainer.new([25, 4], [25])) do
    truthy "the predicate API is used when present", PokeAccess::Util.dex_seen?(4)
    truthy "an owned species reads as owned", PokeAccess::Util.dex_owned?(25)
    falsy "a seen-only species is not owned", PokeAccess::Util.dex_owned?(4)
  end
end

Suite.define("dex flags: predicates on a nested pokedex object") do
  with_player(FakeNestedTrainer.new(FakeNestedDex.new([151], [151]))) do
    truthy "a nested pokedex is probed too", PokeAccess::Util.dex_seen?(151)
    truthy "and for owned as well", PokeAccess::Util.dex_owned?(151)
    falsy "an absent species still reads false", PokeAccess::Util.dex_seen?(1)
  end
end

Suite.define("dex flags: nil when no player and no API") do
  with_player(nil) do
    eq "no player resolves to nil, not false", PokeAccess::Util.dex_seen?(25), nil
  end
  with_player(Object.new) do
    eq "a player with neither API resolves to nil", PokeAccess::Util.dex_seen?(25), nil
  end
end
