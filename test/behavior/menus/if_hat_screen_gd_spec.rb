# Infinite Fusion's hat screen for a Pokemon: picking the hat says it by name as it changes, placing it says where it
# sits, step by step, and when an arrow moves it no further. The presenter and its view are reduced to their loops'
# frames, each one a view update, as the game's run; they are defined before the profile file binds to them.
class PokemonHatView
  def initialize(presenter); @presenter = presenter; end
  def update; nil; end
end

class PokemonHatPresenter
  def initialize(hat_id, x, y)
    @hat_id = hat_id
    @x_pos = x
    @y_pos = y
    @view = PokemonHatView.new(self)
  end

  # The pick's frames: the one it opens on, then one per hat the arrows bring.
  def select_hat(ids = [])
    @view.update
    ids.each { |i| @hat_id = i; @view.update }
    true
  end

  # The placement's frames: the one it opens on, then one per move of [dx, dy] pixels (0, 0 for a blocked press).
  def position_hat(moves = [])
    @view.update
    moves.each { |dx, dy| @x_pos += dx; @y_pos += dy; @view.update }
    true
  end
end

Suite.define("infinite fusion: the hat screen says the hat picked, then where it is placed and its edges") do
  t = PokeAccess::I18n
  hs = nil
  trig = Input.method(:trigger?)
  begin
    load File.expand_path("../../../games/infinitefusion_common/hat_screen.rb", File.dirname(__FILE__))
    hs = PokeAccess::IFHatScreen
    pres = PokemonHatPresenter.new("cap", 0, 0)
    SpeakCapture.clear
    pres.select_hat(["cap", "crown"])
    eq "the pick opens on the hat worn, then says each new one", SpeakCapture.lines,
       [t.t(:if_hat_pick, :name => hs.hat_name("cap")), hs.hat_name("crown")]

    SpeakCapture.clear
    pres.position_hat([[4, 0], [4, 8]])
    eq "the placement opens where the hat sits, then says each step from the picture's corner", SpeakCapture.lines,
       [t.t(:if_hat_place, :where => t.t(:if_hat_corner)),
        t.t(:if_hat_from_corner, :where => PokeAccess::Locator.dir_phrase(1, 0)),
        t.t(:if_hat_from_corner, :where => PokeAccess::Locator.dir_phrase(2, 2))]

    Input.define_singleton_method(:trigger?) { |k| k == Input::RIGHT }
    SpeakCapture.clear
    pres.position_hat([[0, 0]])
    eq "an arrow at the edge moves nothing, and says so", SpeakCapture.lines,
       [t.t(:if_hat_place, :where => t.t(:if_hat_from_corner, :where => PokeAccess::Locator.dir_phrase(2, 2))),
        t.t(:if_hat_edge)]
    Input.define_singleton_method(:trigger?, trig)

    SpeakCapture.clear
    PokemonHatView.new(pres).update
    silent "outside both steps the view's frames say nothing"
  ensure
    Input.define_singleton_method(:trigger?, trig)
  end
end
