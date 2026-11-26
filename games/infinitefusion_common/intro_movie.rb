# The opening animation both Infinite Fusion games play (Movie#playInViewPort, run by Scene_Intro#playIntroCinematic):
# each picture is held through pbWait, hooked to name the movie and to watch confirm on every frame, since the movie's
# own check reads the key once per picture and misses a press made on an earlier one.
module PokeAccess
  module IFIntroMovie
    # Runs one picture's wait, naming the movie on its first and watching confirm where the movie can be cut short.
    def self.picture(movie)
      announce(movie) unless movie.equal?(@named)
      return yield unless PokeAccess.ivar(movie, :@canStopEarly)
      @watching = true
      @pressed = false
      begin
        result = yield
      ensure
        @watching = false
      end
      cut_short(movie) if @pressed
      result
    end

    # Notes a confirm newly pressed on this frame of a watched wait; a key already held when the movie began is not one.
    def self.pulse
      @pressed = true if @watching && ::Input.trigger?(::Input::C)
    end

    # Says the movie's name, queued, with the key that skips it when it can be skipped.
    def self.announce(movie)
      @named = movie
      text = PokeAccess::I18n.t(:if_intro_movie)
      if PokeAccess.ivar(movie, :@canStopEarly)
        key = PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter))
        text = PokeAccess::Verbosity.with_hint(text, PokeAccess::I18n.t(:if_intro_skip, :key => key))
      end
      PokeAccess.speak(text, false)
    end

    # Makes the picture on screen the movie's last, so its loop disposes it and ends as it does after the last one.
    def self.cut_short(movie)
      last = PokeAccess.ivar(movie, :@maxFrame)
      movie.instance_variable_set(:@currentFrame, last) if last.is_a?(Integer)
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  around("Movie", :pbWait) { |movie, wait, _args| PokeAccess::IFIntroMovie.picture(movie) { wait.call } }
  poll_each_frame { PokeAccess::IFIntroMovie.pulse }
end
