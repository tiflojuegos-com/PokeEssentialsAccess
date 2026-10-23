# Anil's punch bag (games/anil/punch_bag.rb): a tick whose pitch rises as the swinging arrow nears the bar's centre,
# and after each hit its stars with the score window, while the game's loop runs. Gamedata pass; the profile file is
# evaluated once over a stand-in of the game's scene, which moves its arrow a frame at a time.
module AnilPunchBagSpec
  ScoreBox = Struct.new(:text)
  Arrow = Struct.new(:visible)

  # The game's scene as the profile reads it: the score window, the arrow and where it swings. pbMain moves the arrow
  # a frame per entry of moves, hides it for the hit, then paints the score and draws the stars.
  class Scene
    BAR_LEFT_SIZE = 128
    attr_accessor :moves, :stars, :score

    def initialize(opening = "Puntos: 0 \nGolpe: 0/10")
      @sprites = { "scorebox" => ScoreBox.new(opening), "arrow" => Arrow.new(true) }
      @arrowXMiddle = 300
      @arrowX = 172
      @moves = []
      @stars = 4
      @score = "Puntos: 4 \nGolpe: 1/10"
    end

    def pbMain(_can_cancel)
      @moves.each do |x|
        @arrowX = x
        PokeAccess::Frame.run_pollers
      end
      @sprites["arrow"].visible = false
      @arrowX = 236
      PokeAccess::Frame.run_pollers
      @sprites["scorebox"].text = @score
      pbDrawStars(@stars)
      12
    end

    def pbDrawStars(_stars); :stars_drawn; end
  end

  class << self
    # Whether the profile file was evaluated over the stand-in, which binds its hooks once per process.
    attr_accessor :loaded
  end
end

class AnilPunchBagGdTest < PokeAccessTest
  Scene = AnilPunchBagSpec::Scene

  test "a tick sounds higher nearer the bar's centre, once per move of the shown arrow" do
    scene = Scene.new
    scene.moves = [172, 236, 300, 300, 364]
    assert_equal [80, 115, 150, 115], ticks { scene.pbMain(true) }, "the far end low, the centre highest, none still"
  end

  test "the hidden arrow sounds no tick" do
    assert_equal [], ticks { Scene.new.pbMain(true) }, "the arrow moved while hidden for the hit"
  end

  test "the tick spans the game's half bar, 128 where it names none" do
    { 128 => [143, 115, 150], 64 => [137, 80, 150], nil => [143, 115, 150] }.each do |half, pitches|
      scene = Scene.new
      scene.moves = [289, 236, 300]
      got = with_half_bar(half) { ticks { scene.pbMain(true) } }
      assert_equal pitches, got, "a half bar of #{half.inspect}"
    end
  end

  test "opening the game says its score window as painted, queued" do
    with_game { Scene.new.pbMain(true) }
    assert_equal ["Puntos: 0 Golpe: 0/10", false], SpeakCapture.log.first
  end

  test "an empty score window says nothing on opening" do
    with_game { Scene.new("").pbMain(true) }
    assert_equal [["#{PokeAccess::I18n.t(:stars_count, :n => 4)}. Puntos: 4 Golpe: 1/10", true]], SpeakCapture.log,
                 "only the hit"
  end

  test "each hit says its stars, then the score as it now reads, cutting in" do
    [4, 1].each do |stars|
      scene = Scene.new
      scene.stars = stars
      SpeakCapture.clear
      with_game { scene.pbMain(true) }
      assert_equal ["#{PokeAccess::I18n.t(:stars_count, :n => stars)}. Puntos: 4 Golpe: 1/10", true],
                   SpeakCapture.log.last, "#{stars} stars"
    end
  end

  test "the game keeps its own result" do
    assert_equal 12, with_game { Scene.new.pbMain(true) }
  end

  test "the arrow is not read once the game's loop has returned" do
    scene = Scene.new
    got = ticks do
      scene.pbMain(true)
      scene.instance_variable_get(:@sprites)["arrow"].visible = true
      scene.instance_variable_set(:@arrowX, 300)
      PokeAccess::Frame.run_pollers
    end
    assert_equal [], got
  end

  private

  # The block's value with the stand-in as the game's PunchBag::Scene, the profile file evaluated over it the first
  # time so its hooks bind; PunchBag is taken away after.
  def with_game
    made = !Object.const_defined?(:PunchBag)
    Object.const_set(:PunchBag, Module.new) if made
    PunchBag.const_set(:Scene, Scene) unless PunchBag.const_defined?(:Scene)
    unless AnilPunchBagSpec.loaded
      path = File.join(Harness::ROOT, "games", "anil", "punch_bag.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      AnilPunchBagSpec.loaded = true
    end
    yield
  ensure
    PokeAccess::AnilPunchBag.release
    Object.send(:remove_const, :PunchBag) if made && Object.const_defined?(:PunchBag)
  end

  # The pitches of the ticks played while the block runs inside the game.
  def ticks
    pitches = nil
    with_cue_log do |log|
      with_game { yield }
      pitches = log.select { |entry| cue_name(entry).include?("pa_mg_tick") }.map { |entry| entry[2] }
    end
    pitches
  end

  # The block's value with the game's half bar set to half, or not named for nil; the game's 128 put back after.
  def with_half_bar(half)
    Scene.send(:remove_const, :BAR_LEFT_SIZE)
    Scene.const_set(:BAR_LEFT_SIZE, half) unless half.nil?
    yield
  ensure
    Scene.send(:remove_const, :BAR_LEFT_SIZE) if Scene.const_defined?(:BAR_LEFT_SIZE, false)
    Scene.const_set(:BAR_LEFT_SIZE, 128)
  end
end
