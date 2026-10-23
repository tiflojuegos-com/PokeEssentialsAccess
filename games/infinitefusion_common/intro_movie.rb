module PokeAccess
  # The opening animation both Infinite Fusion games play before their title (Movie#playInViewPort, run by
  # Scene_Intro#playIntroCinematic): picture frames under music, named as they start, with the confirm key that cuts
  # them short when the movie allows it (@canStopEarly).
  module IFIntroMovie
    def self.started(movie)
      text = PokeAccess::I18n.t(:if_intro_movie)
      if PokeAccess.ivar(movie, :@canStopEarly)
        key = PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter))
        text = PokeAccess::Verbosity.with_hint(text, PokeAccess::I18n.t(:if_intro_skip, :key => key))
      end
      PokeAccess.speak(text, false)
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  before("Movie", :playInViewPort) { |movie, _a| PokeAccess::IFIntroMovie.started(movie) }
end
