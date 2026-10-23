# The locator's verdict cache (Locator.verdict): one verdict per event, live page (the identity of its @list) and kind,
# computed once; a page flip computes anew, flipping back revives the old one, and an event's end, a map change or a
# settings change drops them all.
class VerdictCacheTest < PokeAccessTest
  Locator = PokeAccess::Locator

  test "computes a verdict once and answers the next ask from the cache" do
    sign = World.event(:kind => :sign, :id => 21)
    calls = 0
    first = Locator.verdict(sign, :probe) { calls += 1; :page_a }
    again = Locator.verdict(sign, :probe) { calls += 1; :recomputed }
    assert_equal [:page_a, :page_a, 1], [first, again, calls]
  end

  test "keeps a nil or false verdict without computing it again" do
    sign = World.event(:kind => :sign, :id => 21)
    [nil, false].each do |verdict|
      kind = :"probe_#{verdict.inspect}"
      calls = 0
      Locator.verdict(sign, kind) { calls += 1; verdict }
      again = Locator.verdict(sign, kind) { calls += 1; :recomputed }
      assert_equal [verdict, 1], [again, calls], "a #{verdict.inspect} verdict"
    end
  end

  test "keeps each kind's verdict apart on the same page" do
    sign = World.event(:kind => :sign, :id => 21)
    Locator.verdict(sign, :one) { :first_kind }
    assert_equal :second_kind, Locator.verdict(sign, :two) { :second_kind }
  end

  test "computes anew when the event's page changes" do
    sign = World.event(:kind => :sign, :id => 21)
    Locator.verdict(sign, :probe) { :page_a }
    sign.instance_variable_set(:@list, [TestCmd.new(0)])
    assert_equal :page_b, Locator.verdict(sign, :probe) { :page_b }
  end

  test "revives the first page's verdict when the page flips back" do
    sign = World.event(:kind => :sign, :id => 21)
    page_a = PokeAccess.ivar(sign, :@list)
    Locator.verdict(sign, :probe) { :page_a }
    sign.instance_variable_set(:@list, [TestCmd.new(0)])
    Locator.verdict(sign, :probe) { :page_b }
    sign.instance_variable_set(:@list, page_a)
    calls = 0
    revived = Locator.verdict(sign, :probe) { calls += 1; :recomputed }
    assert_equal [:page_a, 0], [revived, calls]
  end

  test "drops every verdict as an event ends" do
    assert_equal [:after, :after], asked_again_after { run_an_event }
  end

  test "drops every verdict on a map change" do
    assert_equal [:after, :after], asked_again_after { PokeAccess::Events.emit(:map_changed, $game_map.map_id) }
  end

  test "drops every verdict on a settings change" do
    assert_equal [:after, :after], asked_again_after { PokeAccess::Config.set(:transfer_active_page_only, false) }
  end

  test "answers the sign classifier from the cache until the page changes" do
    sign = World.event(:kind => :sign, :id => 21)
    assert_equal true, Locator.sign_event?(sign), "a sprite-less page that shows text is a sign"
    sign.character_name = "npc"
    assert_equal true, Locator.sign_event?(sign), "on the same page the cached verdict stands"
    sign.instance_variable_set(:@list, [TestCmd.new(101, ["Hi"])])
    assert_equal false, Locator.sign_event?(sign), "a new page is classified anew, sprite and all"
  end

  test "keeps a transfer destination for each active-page-only mode, as a profile sets it" do
    door = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(201, [0, 5, 1, 1])],
                        :condition => { :switch1_valid => true, :switch1_id => 60 })
    shut = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(101, ["Cerrado"])])
    ev = TestGameEvent.new(:id => 30, :pages => [shut, door], :active_page => shut)
    $game_map.events[30] = ev
    PokeAccess::Config.transfer_active_page_only = true
    assert_nil Locator.transfer_command_dest_xy(ev), "the active page alone transfers nowhere"
    PokeAccess::Config.transfer_active_page_only = false
    assert_equal [5, 1, 1], Locator.transfer_command_dest_xy(ev), "every page: the door page's destination"
    PokeAccess::Config.transfer_active_page_only = true
    assert_nil Locator.transfer_command_dest_xy(ev), "back on the active page alone, not the other mode's answer"
  end

  test "answers an event it cannot key without the cache, every time" do
    keyless = Object.new
    calls = 0
    2.times { Locator.verdict(keyless, :probe) { calls += 1; :computed } }
    assert_equal 2, calls
  end

  private

  # Caches a :before verdict of two kinds for a sign, runs the block, and returns both verdicts asked again with :after
  # to compute.
  def asked_again_after
    sign = World.event(:kind => :sign, :id => 21)
    [:one, :two].each { |kind| Locator.verdict(sign, kind) { :before } }
    yield
    [:one, :two].map { |kind| Locator.verdict(sign, kind) { :after } }
  end

  # Runs an event and ends it as the map interpreter does, through the locator's watch for the end; the stub
  # interpreter's own running? is put back.
  def run_an_event
    interpreter = $game_system.map_interpreter
    idle = interpreter.method(:running?)
    interpreter.define_singleton_method(:running?) { true }
    Locator.refresh_on_event_end
    interpreter.define_singleton_method(:running?, idle)
    Locator.refresh_on_event_end
  ensure
    interpreter.define_singleton_method(:running?, idle) if idle
  end
end
