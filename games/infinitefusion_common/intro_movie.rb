module PokeAccess
  # The opening animation both Infinite Fusion games play before their title.
  module IFIntroMovie
    def self.play(movie)
      previous_movie, previous_armed = @movie, @armed
      @movie = PokeAccess.ivar(movie, :@canStopEarly) ? movie : nil
      @armed = @movie && !::Input.press?(::Input::C)
      text = PokeAccess::I18n.t(:if_intro_movie)
      if @movie
        key = PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter))
        text = PokeAccess::Verbosity.with_hint(text, PokeAccess::I18n.t(:if_intro_skip, :key => key))
      end
      PokeAccess.speak(text, false)
      yield
    ensure
      @movie, @armed = previous_movie, previous_armed
    end

    # The stock loop checks the trigger once per picture, after several Input.update calls.
    # A held confirm can already have lost its trigger. Let the loop finish and dispose its
    # last picture normally. A key held before the movie must be released first.
    def self.after_wait(movie)
      return unless movie.equal?(@movie)
      unless ::Input.press?(::Input::C)
        @armed = true
        return
      end
      return unless @armed
      last = PokeAccess.ivar(movie, :@maxFrame)
      movie.instance_variable_set(:@currentFrame, last) if last.is_a?(Integer)
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  around("Movie", :playInViewPort) do |movie, play, _args|
    PokeAccess::IFIntroMovie.play(movie, &play)
  end
  after("Movie", :pbWait, :optional => true) do |movie, _result, _args|
    PokeAccess::IFIntroMovie.after_wait(movie)
  end
end
