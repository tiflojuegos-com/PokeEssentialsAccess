# Sevii's Berry Blender (games/sevii/berry_blender.rb) over a stand-in shaped as its script: annoucement is each blend's
# countdown, choice_berry starts each blend, play is one frame of the spin with the circle in @sprites and @speed its
# pace, and the results pages paint with pbDrawTextPositions: a single player's (draw_result_one, which paints @qsym,
# never filled in that mode, and redraw_result_one) and several players' together (draw_for_first_result). Its loop is
# left out: a test turns the circle and runs each paint as a frame would.

SeviiBlenderCircle = Struct.new(:angle)

# The blender: @players holds each player's name, counts (Perfect, Good, Miss) and berry, as the results paint them;
# @perfect, @good and @miss are the single player's own counts.
class BerryBlender
  def initialize(players)
    @players = players
    @qsym = []
    @perfect, @good, @miss = players[0][1]
    @speed = 7
    @maxspeed = 7
    @sprites = { "circle" => SeviiBlenderCircle.new(0) }
  end
  def annoucement; :counted; end
  def choice_berry; :chosen; end
  def play; :played; end

  def draw_result_one
    txtpos = [[_INTL("1. {1}", @players[0][0]), 6, 152, 0, nil, nil]]
    (0..2).each { |i| txtpos.push([_INTL("{1}", @qsym[i]), 230 + 86 * i, 152, 0, nil, nil]) }
    pbDrawTextPositions(nil, txtpos)
  end

  def redraw_result_one
    pbDrawTextPositions(nil, [[_INTL("1. {1}", @players[0][0]), 6, 152, 0, nil, nil],
                              [_INTL("{1}", @players[0][2]), 240, 152, 0, nil, nil],
                              [_INTL("Max speed: {1}", @maxspeed), 170, 92, 0, nil, nil]])
  end

  def draw_for_first_result(number)
    txtpos = []
    (0...number).each { |i| txtpos.push([_INTL("{1}. {2}", i + 1, @players[i][0]), 6, 152 + 32 * i, 0, nil, nil]) }
    (0...number).each do |i|
      (0..2).each { |j| txtpos.push([_INTL("{1}", @players[i][1][j]), 230 + 86 * j, 152 + 32 * i, 0, nil, nil]) }
    end
    pbDrawTextPositions(nil, txtpos)
  end
end

class SeviiBerryBlenderTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "sevii", "berry_blender.rb")
  RED = ["Red", [3, 2, 1], "Cheri Berry"]

  test "the blender is named as its countdown starts, then how to play it, queued, once a blender" do
    self.class.bind
    b = BerryBlender.new([RED])
    assert_equal :counted, b.annoucement
    b.annoucement
    hint = t(:sv_bb_hint, :key => t(:key_enter))
    assert_equal [[PokeAccess::Verbosity.with_hint(t(:sv_bb_title), hint), false]], SpeakCapture.log
  end

  test "the spin plays the tick rising to its highest at the Perfect angle and lower past it, once per angle" do
    self.class.bind
    ticks = spin(BerryBlender.new([RED]), [10, 10, 20, 30, 40, 40, 50, 60, 0])
    assert_equal [0.25, 0.5, 0.75, 1.0, 0.75], ticks
  end

  test "at the pace where the circle turns every frame, each tick sounds a step early, the highest just before 40" do
    self.class.bind
    b = BerryBlender.new([RED])
    b.instance_variable_set(:@speed, 41)
    assert_equal [0.25, 0.5, 0.75, 1.0, 0.75], spin(b, [0, 10, 20, 30, 40, 50])
  end

  test "a single player's counts page, which paints no counts, is said once, queued, with the game's own counts" do
    self.class.bind
    b = BerryBlender.new([RED])
    b.draw_result_one
    b.draw_result_one
    assert_equal [[counts_line(RED), false]], SpeakCapture.log
  end

  test "the second page cuts in with the top speed, then the player and the berry" do
    self.class.bind
    b = BerryBlender.new([RED])
    b.draw_result_one
    b.redraw_result_one
    b.redraw_result_one
    assert_equal [[PokeAccess.sentences(["Max speed: 7", "1. Red, Cheri Berry"]), true]], SpeakCapture.log[1..-1]
  end

  test "another blend says its counts page again, queued, though its counts are the same" do
    self.class.bind
    b = BerryBlender.new([RED])
    b.draw_result_one
    b.redraw_result_one
    b.choice_berry
    b.draw_result_one
    assert_equal [counts_line(RED), false], SpeakCapture.log.last
    assert_equal 3, SpeakCapture.log.length
  end

  test "with more players, the counts page says each player's painted counts as a line of their own" do
    self.class.bind
    blue = ["Blue", [1, 4, 0], "Oran Berry"]
    BerryBlender.new([RED, blue]).draw_for_first_result(2)
    lines = [counts_cells("1. Red", RED), counts_cells("2. Blue", blue)]
    assert_equal [[PokeAccess.sentences(lines), false]], SpeakCapture.log
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  def counts_line(player)
    PokeAccess.sentences([counts_cells("1. #{player[0]}", player)])
  end

  def counts_cells(name, player)
    p, g, m = player[1]
    [name, t(:sv_bb_perfect, :n => p), t(:sv_bb_good, :n => g), t(:sv_bb_miss, :n => m)].join(", ")
  end

  # The fractions of the minigame ticks the blender plays as its circle turns through angles, one frame each.
  def spin(blender, angles)
    circle = blender.instance_variable_get(:@sprites)["circle"]
    gauge_ticks do
      angles.each do |angle|
        circle.angle = angle
        assert_equal :played, blender.play
      end
    end
  end

  # The fractions the block's ticks of the minigame gauge carry, Sound.gauge put back after.
  def gauge_ticks
    ticks = []
    gauge = PokeAccess::Sound.method(:gauge)
    PokeAccess::Sound.define_singleton_method(:gauge) { |fraction| ticks.push(fraction) }
    yield
    ticks
  ensure
    PokeAccess::Sound.define_singleton_method(:gauge, gauge)
  end

  # Evaluates berry_blender.rb once, the profile list put back as it was.
  def self.bind
    return if @bound
    @bound = true
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
    PokeAccess::Game.instance_variable_set(:@profiles, profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
  end
end
