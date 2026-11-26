# Infinite Fusion's opening animation (games/infinitefusion_common/intro_movie.rb) over a stand-in shaped as its Movie:
# playInViewPort's loop, which checks confirm once per picture before holding it through pbWait, a function the movie
# inherits as it inherits the game's from Object, here from a stage class so no other test sees it.

# The game's pbWait: as many frames of Graphics.update and Input.update as asked.
class IfIntroMovieStage
  private

  def pbWait(frames)
    frames.times do
      Graphics.update
      Input.update
    end
  end
end

# The movie: its frames' path, music and length, and whether confirm may cut it short; shown lists the pictures it put up.
class Movie < IfIntroMovieStage
  attr_reader :shown, :finished

  def initialize(framesPath, bgm, maxFrame = 1000, canStopEarly = false)
    @currentFrame = 1
    @maxFrame = maxFrame
    @framesPath = framesPath
    @bgm = bgm
    @canStopEarly = canStopEarly
    @finished = false
  end

  def playInViewPort(_viewport)
    @finished = false
    @currentFrame = 1
    @shown = []
    while @currentFrame <= @maxFrame
      break if Input.trigger?(Input::C) && @canStopEarly
      @shown << @currentFrame
      pbWait(Graphics.frame_rate / 20)
      @currentFrame += 1
    end
    @finished = true
  end
end

class IfIntroMovieGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_common", "intro_movie.rb")
  WAIT = Graphics.frame_rate / 20

  def setup
    super
    self.class.bind
  end

  test "the opening animation is named once as it starts, queued, with the key that skips it" do
    movie = Movie.new("INTRO-%03d", "intro", 4, true)
    with_confirm_on { movie.playInViewPort(nil) }
    assert_equal [1, 2, 3, 4], movie.shown
    skip_hint = t(:if_intro_skip, :key => t(:key_enter))
    assert_equal [[PokeAccess::Verbosity.with_hint(t(:if_intro_movie), skip_hint), false]], SpeakCapture.log
  end

  test "each showing of the movie is named again" do
    with_confirm_on { 2.times { Movie.new("INTRO-%03d", "intro", 2).playInViewPort(nil) } }
    assert_equal [[t(:if_intro_movie), false]] * 2, SpeakCapture.log
  end

  test "a movie that cannot be cut short is named without a key and plays on through confirm" do
    movie = Movie.new("INTRO-%03d", "intro", 4)
    with_confirm_on(1, WAIT + 1, WAIT * 2) { movie.playInViewPort(nil) }
    assert_equal [1, 2, 3, 4], movie.shown
    assert_equal [[t(:if_intro_movie), false]], SpeakCapture.log
  end

  test "the key to skip it is left out while key hints are not said" do
    PokeAccess::Config.verbosity = :brief
    with_confirm_on { Movie.new("INTRO-%03d", "intro", 2, true).playInViewPort(nil) }
    assert_equal [[t(:if_intro_movie), false]], SpeakCapture.log
  end

  test "confirm pressed on a frame the movie's own check never reads ends it once that picture is done" do
    movie = Movie.new("INTRO-%03d", "intro", 10, true)
    with_confirm_on(WAIT + 1) { movie.playInViewPort(nil) }
    assert_equal [1, 2], movie.shown
    assert movie.finished
  end

  test "confirm pressed on the last frame of a wait ends it there as the movie's own check would" do
    movie = Movie.new("INTRO-%03d", "intro", 10, true)
    with_confirm_on(WAIT) { movie.playInViewPort(nil) }
    assert_equal [1], movie.shown
  end

  private

  # Runs the block with confirm newly pressed on the given frames alone, counted by Graphics.update from 1.
  def with_confirm_on(*frames)
    frame = 0
    update = Graphics.method(:update)
    trigger = Input.method(:trigger?)
    Graphics.define_singleton_method(:update) { frame += 1 }
    Input.define_singleton_method(:trigger?) { |button| button == Input::C && frames.include?(frame) }
    yield
  ensure
    Graphics.define_singleton_method(:update, update)
    Input.define_singleton_method(:trigger?, trigger)
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
