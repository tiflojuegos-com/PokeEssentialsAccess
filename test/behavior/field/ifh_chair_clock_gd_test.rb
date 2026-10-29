# Infinite Fusion 2's chairs on the map (games/infinitefusion_hoenn/chair_clock.rb): sitting down is said, queued, with
# the arrows that stand up or move onto the next seat while key hints are said; each jump onto another chair and
# standing up are said, cutting in; outdoors the clock's hour follows the seat, said once, queued, as the clock appears,
# never on its repaints, and the info key on the map says the hour shown now while the clock is up. The player below
# holds Game_Player's name only while the profile binds to it, so the engine stub's player gains no jump.

# The clock's sign window (the game's LocationWindow): the hour it shows and its dispose.
class IfhClockWindow
  attr_accessor :text

  def initialize(text); @text = text; @disposed = false; end
  def dispose; @disposed = true; end
  def disposed?; @disposed; end
end

# The game's clock, down to the window it builds over the hour and the repaint sit_on_chair runs every frame.
def showTimeWindow; IfhClockWindow.new("10:30 PM"); end
def updateTimeWindow(window); window.text = "10:45 PM"; end

# The game's player with its jump toward a direction (Game_Character#jumpTowards), down to the tile it lands on; a
# blocked landing keeps the player where they are.
class IfhChairPlayer < Game_Player
  def jumpTowards(direction)
    return if IfhChairClockGdTest.blocked
    @x += { 4 => -1, 6 => 1 }[direction] || 0
    @y += { 8 => -1, 2 => 1 }[direction] || 0
  end
end

# The chair's sitting loop, down to the clock it shows outdoors and the jumps onto the next chairs the arrows make; it
# returns once an arrow stands the player up.
def sit_on_chair
  showTimeWindow if IfhChairClockGdTest.outdoors
  IfhChairClockGdTest.hops.each { |dir| IfhChairClockGdTest.player.jumpTowards(dir) }
  :stood_up
end

class IfhChairClockGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "chair_clock.rb")

  class << self
    # Whether the chair the stand-in sits on is outdoors, where the game shows its clock; the arrows toward other
    # chairs pressed while seated, whether the next chair blocks the landing, and the player who jumps.
    attr_accessor :outdoors, :hops, :blocked, :player
  end
  self.hops = []

  # Evaluates the profile file once, as boot does, its wraps bound to the chair, the jump and the clock above, with
  # the player above lent Game_Player's name while it binds.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    stub = Object.send(:remove_const, :Game_Player)
    Object.const_set(:Game_Player, IfhChairPlayer)
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    if stub
      Object.send(:remove_const, :Game_Player)
      Object.const_set(:Game_Player, stub)
    end
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  # A player standing in front of the chair.
  def setup
    super
    self.class.player = IfhChairPlayer.new
  end

  # Forgets the clock a test left up, so the map's info key is the trainer's again, and takes the chair back indoors,
  # with no other chair beside it.
  def teardown
    PokeAccess::IF2ChairClock.instance_variable_set(:@window, nil)
    self.class.outdoors = false
    self.class.hops = []
    self.class.blocked = false
    super
  end

  test "the hour is said once, queued, as the clock appears, not on its repaints" do
    win = showTimeWindow
    3.times { updateTimeWindow(win) }
    assert_equal [["10:30 PM", false]], SpeakCapture.log
  end

  test "the info key on the map says the hour the clock shows now, and leaves it once the clock is gone" do
    win = showTimeWindow
    updateTimeWindow(win)
    PokeAccess::Info.set_info(:map, nil)
    assert_equal "10:45 PM", PokeAccess::Info.info_text
    win.dispose
    refute_equal "10:45 PM", PokeAccess::Info.info_text
  end

  test "sitting on a chair is said, queued, with the arrows, and standing up, cutting in, as the loop returns" do
    assert_equal :stood_up, sit_on_chair
    assert_equal [["#{t(:if2_seat)}. #{t(:if2_chair_hint)}", false], [t(:if2_standing), true]], SpeakCapture.log
  end

  test "outdoors the clock's hour follows the seat" do
    self.class.outdoors = true
    sit_on_chair
    assert_equal [["#{t(:if2_seat)}. #{t(:if2_chair_hint)}", false], ["10:30 PM", false], [t(:if2_standing), true]],
                 SpeakCapture.log
  end

  test "the arrows are left out while key hints are not said" do
    PokeAccess::Config.verbosity = :brief
    sit_on_chair
    assert_equal [[t(:if2_seat), false], [t(:if2_standing), true]], SpeakCapture.log
  end

  test "each jump onto another chair is said once, cutting in, and the player lands on it" do
    self.class.hops = [6, 6]
    sit_on_chair
    assert_equal [["#{t(:if2_seat)}. #{t(:if2_chair_hint)}", false], [t(:if2_seat_other), true],
                  [t(:if2_seat_other), true], [t(:if2_standing), true]], SpeakCapture.log
    assert_equal [7, 5], [self.class.player.x, self.class.player.y]
  end

  test "a jump the next chair blocks leaves the player seated and says nothing" do
    self.class.hops = [8]
    self.class.blocked = true
    sit_on_chair
    assert_equal [["#{t(:if2_seat)}. #{t(:if2_chair_hint)}", false], [t(:if2_standing), true]], SpeakCapture.log
  end

  test "a jump of the player's off a chair says nothing" do
    self.class.player.jumpTowards(2)
    assert_equal [], SpeakCapture.log
    assert_equal [5, 6], [self.class.player.x, self.class.player.y]
  end

  test "the engine stub's player, which every other test shares, gains no jump from this file" do
    refute Game_Player.method_defined?(:jumpTowards)
  end

  private

  def t(key)
    PokeAccess::I18n.t(key)
  end
end
