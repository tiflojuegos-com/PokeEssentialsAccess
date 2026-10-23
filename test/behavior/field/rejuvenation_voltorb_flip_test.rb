# Rejuvenation's Voltorb Flip (games/rejuvenation/voltorb_flip.rb): the board's key hint names the A button, which
# opens the notes there, as the player has it, and the quit key as the core does.
class RejuvenationVoltorbFlipTest < PokeAccessTest
  class << self
    # The profile's key hint, kept aside by load_profile.
    attr_reader :keys
  end

  # Evaluates the profile file once, as boot does. Its key hint is kept aside, and the core's and the lists of
  # profiles and overrides put back, so the other tests of the process keep the core's; with_profile_keys puts the
  # profile's in for a test.
  def self.load_profile
    overrides = PokeAccess::Hooks.overrides.length
    meta = PokeAccess::Minigames.singleton_class
    core = meta.instance_method(:vf_keys)
    profiles = PokeAccess::Game.profiles.dup
    path = File.join(Harness::ROOT, "games", "rejuvenation", "voltorb_flip.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    @keys = meta.instance_method(:vf_keys)
  ensure
    meta.send(:define_method, :vf_keys, core)
    PokeAccess::Game.profiles.replace(profiles)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
  end
  load_profile

  test "the board's hint names the A button for the notes, Z by default, and X to quit" do
    with_profile_keys do
      assert_equal "#{t(:mg_vf_memo_key, :key => 'Z')}. #{t(:piano_exit, :key => 'X')}", PokeAccess::Minigames.vf_keys
    end
  end

  test "the notes key is the one the player bound to the A button" do
    PokeAccess::Config.rebinds = { :a => 0x46 }
    with_profile_keys do
      notes = t(:mg_vf_memo_key, :key => PokeAccess::ConfigMenu.keyname(0x46))
      assert_equal "#{notes}. #{t(:piano_exit, :key => 'X')}", PokeAccess::Minigames.vf_keys
    end
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # Runs the block with the profile's key hint in place of the core's, put back after.
  def with_profile_keys
    meta = PokeAccess::Minigames.singleton_class
    was = meta.instance_method(:vf_keys)
    meta.send(:define_method, :vf_keys, self.class.keys)
    yield
  ensure
    meta.send(:define_method, :vf_keys, was)
  end
end
