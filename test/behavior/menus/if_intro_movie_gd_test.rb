# Infinite Fusion's opening animation (games/infinitefusion_common/intro_movie.rb) over a stand-in shaped as its Movie:
# @canStopEarly set by its fourth argument, playInViewPort the loop that shows its frames, left out.

# The movie: its frames' path, music and length, and whether confirm may cut it short.
class Movie
  def initialize(framesPath, bgm, maxFrame = 1000, canStopEarly = false)
    @framesPath = framesPath
    @bgm = bgm
    @maxFrame = maxFrame
    @canStopEarly = canStopEarly
  end
  attr_accessor :waits
  attr_reader :frames_after_wait

  def playInViewPort(_viewport)
    @currentFrame = 1
    @frames_after_wait = []
    @waits.to_i.times do
      pbWait(1)
      @frames_after_wait << @currentFrame
      @currentFrame += 1
      break if @currentFrame > @maxFrame
    end
    :played
  end

  private

  def pbWait(_frames); end
end

class IfIntroMovieGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_common", "intro_movie.rb")

  test "the opening animation is named as it starts, queued, with the key that skips it" do
    self.class.bind
    assert_equal :played, Movie.new("INTRO-%03d", "intro", 230, true).playInViewPort(nil)
    skip_hint = t(:if_intro_skip, :key => t(:key_enter))
    assert_equal [[PokeAccess::Verbosity.with_hint(t(:if_intro_movie), skip_hint), false]], SpeakCapture.log
  end

  test "a movie that cannot be cut short is named without a key" do
    self.class.bind
    Movie.new("INTRO-%03d", "intro").playInViewPort(nil)
    assert_equal [[t(:if_intro_movie), false]], SpeakCapture.log
  end

  test "the key to skip it is left out while key hints are not said" do
    self.class.bind
    PokeAccess::Config.verbosity = :brief
    Movie.new("INTRO-%03d", "intro", 230, true).playInViewPort(nil)
    assert_equal [[t(:if_intro_movie), false]], SpeakCapture.log
  end

  test "a held confirm ends a skippable movie through its normal loop even if the trigger is gone" do
    self.class.bind
    movie = Movie.new("INTRO-%03d", "intro", 10, true)
    movie.waits = 4
    with_confirm_states(false, true) { assert_equal :played, movie.playInViewPort(nil) }
    assert_equal [10], movie.frames_after_wait
  end

  test "confirm held when the movie starts must be released before it can skip" do
    self.class.bind
    movie = Movie.new("INTRO-%03d", "intro", 10, true)
    movie.waits = 4
    with_confirm_states(true, true, false, true) { movie.playInViewPort(nil) }
    assert_equal [1, 2, 10], movie.frames_after_wait
  end

  test "a movie that cannot be skipped plays on when confirm is held" do
    self.class.bind
    movie = Movie.new("INTRO-%03d", "intro", 10)
    movie.waits = 3
    with_confirm_states(true, true, true, true) { movie.playInViewPort(nil) }
    assert_equal [1, 2, 3], movie.frames_after_wait
  end

  private

  def with_confirm_states(*states)
    original = Input.method(:press?)
    Input.define_singleton_method(:press?) { |button| button == Input::C && states.shift }
    yield
  ensure
    Input.define_singleton_method(:press?, original)
  end

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Evaluates intro_movie.rb once, the profile list put back as it was.
  def self.bind
    return if @bound
    @bound = true
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
    PokeAccess::Game.instance_variable_set(:@profiles, profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
  end
end
