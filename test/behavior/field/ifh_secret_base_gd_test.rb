# Infinite Fusion 2's secret base seats (games/infinitefusion_hoenn/secret_base.rb): sitting down is said, then the key
# that stands the player up while key hints are said.

# The seat's jump and wait, down to its argument; it returns once an arrow stands the player up.
def sit_on_chair_event(_event); :stood_up; end

class IfhSecretBaseGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "secret_base.rb")

  # Evaluates the profile file once, as boot does, its wrap bound to the stand-in above.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  test "sitting down is said, queued, with the key that stands up, and the seat keeps the game's result" do
    assert_equal :stood_up, sit_on_chair_event(nil)
    assert_equal [["#{t(:if2_seat)}. #{t(:if2_seat_hint)}", false]], SpeakCapture.log
  end

  test "the key is left out while key hints are not said" do
    PokeAccess::Config.verbosity = :brief
    sit_on_chair_event(nil)
    assert_equal [[t(:if2_seat), false]], SpeakCapture.log
  end

  private

  def t(key)
    PokeAccess::I18n.t(key)
  end
end
