# The keyboard routes for realidea's mouse-only minigames (games/realidea/mouse_minigames.rb). Each
# handler replaces the game's per-frame input wholesale, so the stubs' always-false Input would leave every
# branch unexercised: ReaKeys overrides Input.trigger? for the duration of one call, which is exactly how a
# keypress reaches the handler in the game (one frame, one edge). The fake scenes carry the ivars and the
# logic methods each dump keeps mouse-free, so the tests pin the contract the readers rely on: which ivar
# holds the cursor, which method resolves an action, and what is spoken when.
require File.expand_path("../../../games/realidea/mouse_minigames", File.dirname(__FILE__))

module ReaKeys
  @keys = []
  def self.pressed?(k); @keys.include?(k); end

  # Runs the block with exactly these virtual buttons reporting a trigger this frame.
  def self.press(*keys)
    @keys = keys
    yield
  ensure
    @keys = []
  end

  def self.install
    return if @installed
    @installed = true
    class << Input
      alias_method :pa_spec_orig_trigger?, :trigger?
      def trigger?(k); ReaKeys.pressed?(k) || pa_spec_orig_trigger?(k); end
    end
  end

  def self.remove
    return unless @installed
    @installed = false
    class << Input
      alias_method :trigger?, :pa_spec_orig_trigger?
    end
  end
end

def rea_t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

# ---- Cockteles ----
class ReaSpecCockteles
  attr_accessor :player
  def initialize
    @seleccion = "morado"
    @player = []
    @intentos = 0
    @victorias = 0
    @derrotas = 0
    @sprites = {}
  end

  # The dump's colorescopa: one bottle only fills the glass; two resolve the round, count it and pick the
  # next cocktail. The mix table is reduced to the one pair the test pours.
  def colorescopa
    return if @player.length < 2
    hit = @player.sort == ["azul", "rojo"] && @seleccion == "morado"
    if hit then @victorias += 1 else @derrotas += 1 end
    @intentos = @victorias + @derrotas
    @player = []
    @seleccion = "verde"
  end
end

Suite.define("realidea cockteles: target, bottles, pours and the round's verdict by keyboard") do
  ReaKeys.install
  begin
    s = ReaSpecCockteles.new
    SpeakCapture.clear
    PokeAccess::ReaMouse.ck_input(s)
    spoke "the round's target cocktail is announced on the first frame", /#{Regexp.escape(rea_t(:rmg_ck_target, :name => rea_t(:rmg_ck_morado)))}/
    SpeakCapture.clear
    PokeAccess::ReaMouse.ck_input(s)
    silent "and not again while the target stands"

    ReaKeys.press(Input::RIGHT) { PokeAccess::ReaMouse.ck_input(s) }
    spoke "right moves to the second bottle", /\A#{Regexp.escape(rea_t(:rmg_azul))}\z/
    SpeakCapture.clear
    ReaKeys.press(Input::C) { PokeAccess::ReaMouse.ck_input(s) }
    spoke "confirm pours it and asks for the second", /#{Regexp.escape(rea_t(:rmg_ck_poured, :name => rea_t(:rmg_azul)))}/
    eq "the bottle went into the game's own glass", s.player, ["azul"]

    SpeakCapture.clear
    ReaKeys.press(Input::LEFT) { PokeAccess::ReaMouse.ck_input(s) }
    ReaKeys.press(Input::C) { PokeAccess::ReaMouse.ck_input(s) }
    spoke "the second pour resolves the round through colorescopa and speaks the verdict",
          /#{Regexp.escape(rea_t(:rmg_ck_hit, :v => 1, :n => 1, :tot => 9))}/
    SpeakCapture.clear
    PokeAccess::ReaMouse.ck_input(s)
    spoke "the next round's target follows, queued behind the verdict", /#{Regexp.escape(rea_t(:rmg_verde))}/
    eq "queued, not interrupting", SpeakCapture.log.last[1], false
  ensure
    ReaKeys.remove
    SpeakCapture.clear
  end
end

# ---- Tresenraya ----
class ReaSpecSprite
  attr_accessor :x, :y, :bitmap
  def initialize(x = 0, y = 0); @x = x; @y = y; end
  def setBitmap(path); @bitmap = path; end
  def disposed?; false; end
end

class ReaSpecTresenraya
  attr_reader :cerrar, :turno, :playpos, :enempos
  def initialize
    @playpos = Array.new(4) { Array.new(4, false) }
    @enempos = Array.new(4) { Array.new(4, false) }
    @turno = 0
    @resultado = 0
    @cerrar = 0
    @sprites = {}
    (1..3).each { |i| (1..3).each { |j| @sprites["hueco#{i}_#{j}"] = ReaSpecSprite.new } }
  end
  def comprobar; end
  def turnoenemigo
    @enempos[1][1] = true
    @turno = 0
  end
end

Suite.define("realidea tres en raya: cursor over the grid, a placed cross and the rival's answer") do
  ReaKeys.install
  begin
    s = ReaSpecTresenraya.new
    SpeakCapture.clear
    ReaKeys.press(Input::DOWN) { PokeAccess::ReaMouse.ttt_input(s) }
    spoke "the cursor starts on the centre and speaks the cell it lands on",
          /#{Regexp.escape(rea_t(:rmg_ttt_cell, :row => 3, :col => 2, :state => rea_t(:rmg_ttt_free)))}/
    SpeakCapture.clear
    ReaKeys.press(Input::C) { PokeAccess::ReaMouse.ttt_input(s) }
    truthy "confirm places the player's cross through the game's own board", s.playpos[3][2]
    eq "and paints the cross bitmap the game paints", s.instance_variable_get(:@sprites)["hueco3_2"].bitmap, "Graphics/Pictures/Tresenraya/cruz"
    spoke "the placement is spoken", /#{Regexp.escape(rea_t(:rmg_ttt_placed, :row => 3, :col => 2))}/
    spoke "and the rival's answer, made inside the same frame, is spoken after it",
          /#{Regexp.escape(rea_t(:rmg_ttt_enemy_move, :row => 1, :col => 1))}/
    eq "the turn came back to the player", s.turno, 0

    SpeakCapture.clear
    ReaKeys.press(Input::C) { PokeAccess::ReaMouse.ttt_input(s) }
    silent "confirm on an occupied cell does nothing"
    ReaKeys.press(Input::B) { PokeAccess::ReaMouse.ttt_input(s) }
    eq "back raises the game's own close flag", s.cerrar, 1
  ensure
    ReaKeys.remove
    SpeakCapture.clear
  end
end

# ---- Menuminior ----
Suite.define("realidea minior menu: difficulty rows and the painted help, deduped") do
  s = Object.new
  s.instance_variable_set(:@selec, 0)
  s.instance_variable_set(:@info, 0)
  SpeakCapture.clear
  PokeAccess::ReaMouse.mm_after(s)
  spoke "the focused difficulty is named on the first frame", /#{Regexp.escape(rea_t(:rmg_mm_easy))}/
  SpeakCapture.clear
  PokeAccess::ReaMouse.mm_after(s)
  silent "and not repeated while it stands"
  s.instance_variable_set(:@selec, 2)
  PokeAccess::ReaMouse.mm_after(s)
  spoke "moving speaks the new row", /#{Regexp.escape(rea_t(:rmg_mm_hard))}/
  SpeakCapture.clear
  s.instance_variable_set(:@info, 1)
  PokeAccess::ReaMouse.mm_after(s, ["¡Haz click sobre los Miniors que estén al lado de otros del mismo color!"])
  spoke "the help overlay speaks the game's own painted instructions", /Miniors/
  SpeakCapture.clear
  PokeAccess::ReaMouse.mm_after(s, [])
  silent "once"
  SpeakCapture.clear
end

# ---- Miniorgame ----
class ReaSpecMinior
  attr_reader :color
  def initialize(color); @color = color; end
end

class ReaSpecMiniorgame
  attr_reader :cerrar, :reset
  def initialize
    @miniorsmatrix = Array.new(10) { |r| Array.new(9) { |c| ReaSpecMinior.new(r == 9 && c < 3 ? "miniorrojo" : "miniorverde") } }
    @total = 0
    @count = 90
    @cerrar = 0
    @reset = 0
  end
  def contar_vecinos(r, c, color); (r == 9 && c < 3) ? 3 : 1; end
  def buscarvecinos(r, c, color)
    @total += 30
    @count -= 3
  end
end

Suite.define("realidea minior board: a cell names its colour and group, confirm bursts a group and the score follows") do
  ReaKeys.install
  begin
    s = ReaSpecMiniorgame.new
    SpeakCapture.clear
    ReaKeys.press(Input::RIGHT) { PokeAccess::ReaMouse.mg_input(s) }
    spoke "the cursor starts bottom-left and moving speaks colour, group size and position",
          /#{Regexp.escape(rea_t(:rmg_mg_cell, :color => rea_t(:rmg_rojo), :n => 3, :row => 10, :col => 2))}/
    SpeakCapture.clear
    ReaKeys.press(Input::C) { PokeAccess::ReaMouse.mg_input(s) }
    PokeAccess::ReaMouse.mg_input(s)
    spoke "confirm on a group bursts it through the game and the new score is spoken on the next frame",
          /#{Regexp.escape(rea_t(:rmg_mg_score, :pts => 30, :left => 87))}/
    SpeakCapture.clear
    ReaKeys.press(Input::UP) { PokeAccess::ReaMouse.mg_input(s) }
    SpeakCapture.clear
    ReaKeys.press(Input::C) { PokeAccess::ReaMouse.mg_input(s) }
    spoke "confirm on a lone minior explains why nothing happened", /#{Regexp.escape(rea_t(:rmg_mg_no_group))}/
    ReaKeys.press(Input::B) { PokeAccess::ReaMouse.mg_input(s) }
    eq "back raises the game's close flag", s.cerrar, 1
    ReaKeys.press(Input::A) { PokeAccess::ReaMouse.mg_input(s) }
    eq "A raises the game's reset flag", s.reset, 1
  ensure
    ReaKeys.remove
    SpeakCapture.clear
  end
end

# ---- Unowngame ----
class ReaSpecUnowngame
  attr_reader :puntuacion1, :puntuacion2, :sprites
  VALUES = { "M" => 1000, "D" => 500, "C" => 100, "L" => 50, "X" => 10, "V" => 5, "I" => 1 }
  def initialize
    @limite = 225
    @sprites = {}
    { "M" => 3, "D" => 4, "C" => 4, "L" => 2, "I" => 2, "V" => 2 }.each do |letter, n|
      n.times { |i| @sprites["#{letter}#{i}"] = ReaSpecSprite.new(100, 50) }
    end
    @sprites["X"] = ReaSpecSprite.new(300, 50)
    puntuacion
  end

  # The dump recomputes both sides from every piece's x against the split: right side scores 1, left side 2.
  def puntuacion
    @puntuacion1 = 0
    @puntuacion2 = 0
    @sprites.each do |key, sp|
      v = VALUES[key[0, 1]]
      if sp.x >= @limite then @puntuacion1 += v else @puntuacion2 += v end
    end
  end
end

Suite.define("realidea unown balance: pieces by value and side, an atomic move across, and the totals") do
  ReaKeys.install
  begin
    s = ReaSpecUnowngame.new
    eq "fixture: everything but the X starts on the left", [s.puntuacion1, s.puntuacion2], [10, 5512]
    SpeakCapture.clear
    ReaKeys.press(Input::RIGHT) { PokeAccess::ReaMouse.un_input(s) }
    spoke "moving names the piece, its value and its side",
          /#{Regexp.escape(rea_t(:rmg_un_piece, :letter => "M", :value => 1000, :side => rea_t(:rmg_un_left)))}/
    SpeakCapture.clear
    ReaKeys.press(Input::C) { PokeAccess::ReaMouse.un_input(s) }
    spoke "confirm carries the piece to the other side in one frame and speaks both totals",
          /#{Regexp.escape(rea_t(:rmg_un_moved, :letter => "M", :right => 1010, :left => 4512))}/
    truthy "the piece really crossed the split", s.sprites["M1"].x >= 225
    eq "and the game's selection was released within the frame", s.instance_variable_get(:@seleccion), nil
    SpeakCapture.clear
    ReaKeys.press(Input::A) { PokeAccess::ReaMouse.un_input(s) }
    spoke "A reads the totals on demand", /#{Regexp.escape(rea_t(:rmg_un_totals, :right => 1010, :left => 4512))}/
  ensure
    ReaKeys.remove
    SpeakCapture.clear
  end
end

# ---- Perlita ----
class ReaSpecPerlita
  attr_reader :victorias, :derrotas, :sprites
  def initialize
    @saquito = "azul"
    @victorias = 0
    @derrotas = 0
    @sprites = { "sacoazul" => ReaSpecSprite.new(60, 100), "sacoamarillo" => ReaSpecSprite.new(210, 100),
                 "sacorojo" => ReaSpecSprite.new(360, 100), "bocadillo" => ReaSpecSprite.new,
                 "bolabocadillo" => ReaSpecSprite.new }
    @sprites.each_value { |sp| sp.instance_variable_set(:@visible, false) }
    @sprites.each_value { |sp| sp.define_singleton_method(:visible=) { |v| @visible = v } }
  end
  def abrirsaquito
    if @respuesta == @saquito then @victorias += 1 else @derrotas += 1 end
  end
end

Suite.define("realidea perlita: the shell game is followed by position, never by bag name") do
  ReaKeys.install
  begin
    s = ReaSpecPerlita.new
    SpeakCapture.clear
    PokeAccess::ReaMouse.pl_target(s)
    spoke "the round names the pearl to find", /#{Regexp.escape(rea_t(:rmg_pl_target, :color => rea_t(:rmg_pl_azul)))}/
    spoke "and where each pearl goes before the bags close, as the screen shows it",
          /#{Regexp.escape(rea_t(:rmg_pl_layout, :l => rea_t(:rmg_pl_azul), :c => rea_t(:rmg_pl_amarilla), :r => rea_t(:rmg_pl_roja)))}/

    before = {}
    PokeAccess::ReaMouse.pl_sorted(s).each { |sp, k| before[k] = sp.x }
    s.sprites["sacoazul"].x, s.sprites["sacoamarillo"].x = 210, 60
    SpeakCapture.clear
    PokeAccess::ReaMouse.pl_swap(s, before)
    spoke "a shuffle is spoken as the two POSITIONS that crossed, not as which bags they were",
          /#{Regexp.escape(rea_t(:rmg_pl_swap, :a => rea_t(:rmg_pl_left), :b => rea_t(:rmg_pl_center)))}/
    falsy "no bag colour leaks through the shuffle", SpeakCapture.log.any? { |t, _| t =~ /#{rea_t(:rmg_pl_azul)}/ }

    SpeakCapture.clear
    ReaKeys.press(Input::LEFT) { PokeAccess::ReaMouse.pl_input(s) }
    spoke "the cursor speaks positions only", /\A#{Regexp.escape(rea_t(:rmg_pl_left))}\z/
    SpeakCapture.clear
    ReaKeys.press(Input::C) { PokeAccess::ReaMouse.pl_input(s) }
    eq "confirm on the left position opens the bag that is NOW there (the yellow one) and the game counts a miss",
       [s.victorias, s.derrotas], [0, 1]
    spoke "and the verdict is spoken with the round count", /#{Regexp.escape(rea_t(:rmg_ck_miss, :v => 0, :n => 1, :tot => 5))}/

    SpeakCapture.clear
    ReaKeys.press(Input::RIGHT) { PokeAccess::ReaMouse.pl_input(s) }
    ReaKeys.press(Input::C) { PokeAccess::ReaMouse.pl_input(s) }
    eq "following the crossing to the centre finds the blue bag", [s.victorias, s.derrotas], [1, 1]
  ensure
    ReaKeys.remove
    SpeakCapture.clear
  end
end
