# Insurgence's H-Mode7 switch (games/insurgence/hm7.rb) reads false whatever the game stores, through a plain method
# rather than a hook, so no read of it escapes, not even one inside another hooked method; the value the game stores
# is left as it is.

# Game_System as Insurgence extends it: the H-Mode7 switch, before the profile file reads it.
class Game_System
  attr_accessor :hm7
end

hm7_path = File.join(Harness::ROOT, "games", "insurgence", "hm7.rb")
eval(Harness.source(hm7_path), TOPLEVEL_BINDING, hm7_path)

class InsurgenceHm7Test < PokeAccessTest
  test "the switch reads false once the game turns it on" do
    assert_equal false, switched_on.hm7
  end

  test "the switch reads false inside another hooked method too" do
    system = switched_on
    assert_equal false, PokeAccess::Hooks.guarded(:update) { system.hm7 }
  end

  test "the value the game stores, which its save keeps, is left as it was" do
    assert_equal true, switched_on.instance_variable_get(:@hm7)
  end

  private

  # A Game_System the game has turned H-Mode7 on in.
  def switched_on
    system = Game_System.new
    system.hm7 = true
    system
  end
end
