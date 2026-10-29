# The PC Hall of Fame of both Infinite Fusion games (games/infinitefusion_common/hall_of_fame_pc.rb): past a record's
# last member the viewer shows the record's entry page, said as painted and cutting in; turning between that page and
# a member reads each again, in the order the game's pbUpdatePC paints them.

# The entry page as both games paint it: the title (Hoenn's with its rematch tier, from @if_entry_title), the record's
# date, then its mode with the difficulty. The member panel is the engine stub's, inherited; the scene holds
# HallOfFame_Scene's name only while the profile binds to it, so the stub every Hall of Fame test shares gains no page.
class IfHofPcScene < HallOfFame_Scene
  def writeWelcomePC
    pbDrawTextPositions(nil, [[@if_entry_title || "Entered the Hall of Fame!", 256, 304, 2]])
    pbDrawTextPositions(nil, [["2026-10-29", 120, 334, 2]])
    pbDrawTextPositions(nil, [["Classic mode (Normal)", 356, 334, 2]])
    :entry
  end
end

class IfHallOfFamePcGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_common", "hall_of_fame_pc.rb")
  ENTRY = "Entered the Hall of Fame!, 2026-10-29, Classic mode (Normal)"
  Member = Struct.new(:name, :level, :species)

  # The member panel's hook chain, which core bound on the engine stub every Hall of Fame test shares.
  PANEL = "HallOfFame_Scene#writePokemonData"

  class << self
    # The profile's hooks on the member panel, kept out of that shared chain but while this file's tests run.
    attr_reader :panel_hooks
  end

  # Evaluates the profile file once, as boot does, its hooks bound to the scene above, lent HallOfFame_Scene's name
  # while they bind; the hooks it adds to the shared panel chain are taken back out and kept aside.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    shared = (chains[PANEL] || []).dup
    stub = Object.send(:remove_const, :HallOfFame_Scene)
    Object.const_set(:HallOfFame_Scene, IfHofPcScene)
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    if stub
      Object.send(:remove_const, :HallOfFame_Scene)
      Object.const_set(:HallOfFame_Scene, stub)
    end
    after = chains[PANEL] || []
    @panel_hooks = after.reject { |w| shared.any? { |s| s.equal?(w) } }
    after.replace(shared)
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  # Puts the profile's panel hooks back in the shared chain for this test alone.
  def setup
    super
    chain = (PokeAccess::Hooks.instance_variable_get(:@chains)[PANEL] ||= [])
    self.class.panel_hooks.each { |w| chain.push(w) unless chain.any? { |c| c.equal?(w) } }
  end

  # Takes the profile's panel hooks out of the shared chain again.
  def teardown
    detach_panel_hooks
    super
  end

  test "the profile's panel hook joins the shared Hall of Fame chain only while this file's tests run" do
    chain = PokeAccess::Hooks.instance_variable_get(:@chains)[PANEL]
    hooks = self.class.panel_hooks
    refute_empty hooks
    assert hooks.all? { |w| chain.any? { |c| c.equal?(w) } }, "in the chain during the test"
    detach_panel_hooks
    refute hooks.any? { |w| chain.any? { |c| c.equal?(w) } }, "out of it once the test is over"
  end

  test "the entry page past the last member is said as painted, cutting in, and keeps the game's result" do
    assert_equal :entry, IfHofPcScene.new.writeWelcomePC
    assert_equal [[ENTRY, true]], SpeakCapture.log
  end

  test "Hoenn's rematch tier is said with the title it is painted in" do
    scene = IfHofPcScene.new
    scene.instance_variable_set(:@if_entry_title, "Entered the Hall of Fame! (Rematch Tier 2)")
    scene.writeWelcomePC
    assert_equal [["Entered the Hall of Fame! (Rematch Tier 2), 2026-10-29, Classic mode (Normal)", true]],
                 SpeakCapture.log
  end

  test "turning back from the entry page reads the last member again, a repaint with no turn still once" do
    scene = IfHofPcScene.new
    last = Member.new("Brasa", 40, 4)
    2.times { scene.writePokemonData(last, 1) }
    scene.writeWelcomePC
    scene.writePokemonData(last, 1)
    assert_equal [[panel(last), true], [ENTRY, true], [panel(last), true]], SpeakCapture.log
  end

  test "each visit to the entry page reads it, though it paints the same" do
    scene = IfHofPcScene.new
    last = Member.new("Brasa", 40, 4)
    scene.writeWelcomePC
    scene.writePokemonData(last, 1)
    scene.writeWelcomePC
    assert_equal [[ENTRY, true], [panel(last), true], [ENTRY, true]], SpeakCapture.log
  end

  test "the engine stub's scene, which every other Hall of Fame test shares, gains no entry page from this file" do
    refute HallOfFame_Scene.method_defined?(:writeWelcomePC)
  end

  private

  # Takes the profile's panel hooks out of the shared chain.
  def detach_panel_hooks
    chain = PokeAccess::Hooks.instance_variable_get(:@chains)[PANEL]
    chain.delete_if { |c| self.class.panel_hooks.any? { |w| w.equal?(c) } } if chain
  end

  # A member panel as the stub paints it in the PC viewer: the dex number, then the member's name and level.
  def panel(member)
    "No. 025, #{member.name} Lv. #{member.level}"
  end
end
