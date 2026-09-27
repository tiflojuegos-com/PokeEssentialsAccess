# Realidea's blocking-loop minigames (games/realidea/minigames.rb): the type duel, the dance and the berry parfait,
# their readers on plain scenes carrying the ivars each game keeps, and every loop entered through the game's own
# method on a stand-in that exists before the profile loads, so its hooks bind to it as they do in the game.

# Runs the frames a stand-in's loop is handed: each one's ivar changes are left on the scene, as the game's own
# frame work leaves them, then the frame is drawn and the input read, and the block runs the frame's own step.
def rea_mini_frames(scene, steps)
  (steps || []).each do |changes|
    changes.each { |k, v| scene.instance_variable_set(k, v) }
    Graphics.update
    Input.update
    yield if block_given?
  end
end

# The type duel (Pelea tipos), the dance (Bailedoki) and the parfait (Postresjuego), down to the blocking loop each
# runs until it ends; @steps holds its frames.
class PPT
  def update; rea_mini_frames(self, @steps); end
end

class Bailedoki
  def actu; rea_mini_frames(self, @steps); end
end

class Postresjuego
  def actu; rea_mini_frames(self, @steps); end
end

# The berry parfait (Postresjuegobaya): each frame of actu runs input, which catches a berry falling in the cursor's
# column over the glass (y 280 to 330), hides it and adds it to the glass (@pisodefault1); a berry that breaks the
# recipe (@pisodefault0), or the third, empties the glass and redraws the recipe, marking the parfait won when it
# matched. Then every shown berry falls 8 px, and one past the bottom is hidden again.
class Postresjuegobaya
  JARS = { "Chesto" => "Atania", "Cheri" => "Zreza", "Pecha" => "Meloc", "Rawst" => "Safre" }
  COLUMNS = [115, 210, 305]

  def input
    (0...5).each do |i|
      icon = @sprites["icono#{i}"]
      next unless icon.y > 280 && icon.y < 330 && icon.x == COLUMNS[@cursor]
      icon.y = -15
      icon.visible = false
      berry = icon.name.split("/").last
      @pisodefault1.push(JARS[berry] || berry)
      next unless @pisodefault1.length == 3 || @pisodefault1.last != @pisodefault0[@pisodefault1.length - 1]
      @ganado = true if @pisodefault1 == @pisodefault0
      @pisodefault0.clear
      @pisodefault1.clear
      dibujarjarraejemplo
    end
  end

  def dibujarjarraejemplo
    $Trainer.receta.each { |b| @pisodefault0.push(JARS[b] || b) }
  end

  def actu
    rea_mini_frames(self, @steps) do
      input
      (0...5).each do |i|
        icon = @sprites["icono#{i}"]
        icon.y += 8 if icon.visible
        next unless icon.y > 400
        icon.y = -15
        icon.visible = false
      end
    end
  end
end

require File.expand_path("../../../games/realidea/minigames", File.dirname(__FILE__))

# A sprite as the readers see it: shown or not, where, and the picture it carries.
class ReaMiniSprite
  attr_accessor :visible, :x, :y, :name
  def initialize(visible = true, x = 0, y = 0, name = ""); @visible = visible; @x = x; @y = y; @name = name; end
end

# A plain object carrying the given ivars, as the game's scene carries them.
def rea_mini_scene(ivars)
  s = Object.new
  ivars.each { |k, v| s.instance_variable_set(k, v) }
  s
end

# One of the minigames with the given ivars, built without its initializer (which runs the whole loop).
def rea_mini_game(klass, ivars)
  s = klass.allocate
  ivars.each { |k, v| s.instance_variable_set(k, v) }
  s
end

def rea_mt(key, vars = nil); PokeAccess::I18n.t(key, vars); end

Suite.define("realidea type duel: the rival's type as it slides in, the time a choice has, and a lost round") do
  rm = PokeAccess::RealideaMinigames
  scene = rea_mini_scene(:@selector => 0, :@fase => 0, :@comb => ["Agua", "Fuego", "Planta"], :@protahp => 180,
                         :@enemhp => 180, :@tiempo2 => 60, :@frames => 0, :@sprites => {})
  rm.ppt(scene)
  eq "the focused type first, then the time each choice has, queued", SpeakCapture.log,
     [[rea_mt(:rea_ppt, :name => "Agua", :hp => 180, :ehp => 180), true],
      [rea_mt(:rea_ppt_time, :t => "1,5 #{rea_mt(:secs, :n => 1.5)}"), false]]

  SpeakCapture.clear
  scene.instance_variable_set(:@fase, 1)
  scene.instance_variable_set(:@enemigo, "2")
  scene.instance_variable_set(:@sprites, { "Icon0" => ReaMiniSprite.new(true), "Icon2" => ReaMiniSprite.new(false) })
  rm.ppt(scene)
  silent "nothing before the rival's icon is out"
  scene.instance_variable_get(:@sprites)["Icon2"].visible = true
  rm.ppt(scene)
  eq "the rival's type as its icon slides in", SpeakCapture.lines, [rea_mt(:rea_ppt_rival, :name => "Planta")]
  SpeakCapture.clear
  rm.ppt(scene)
  silent "and once per round"

  scene.instance_variable_set(:@fase, 2)
  rm.ppt(scene)
  scene.instance_variable_set(:@fase, 1)
  rm.ppt(scene)
  spoke_once "a new round with the same rival type says it again", /#{Regexp.escape(rea_mt(:rea_ppt_rival, :name => "Planta"))}/

  scene.instance_variable_set(:@fase, 2)
  rm.ppt(scene)
  SpeakCapture.clear
  scene.instance_variable_set(:@frames, 60)
  rm.ppt(scene)
  eq "a choice that runs out is said as it runs out", SpeakCapture.log, [[rea_mt(:rea_ppt_timeout), true]]
  scene.instance_variable_set(:@protahp, 160)
  rm.ppt(scene)
  eq "and the HP it costs queued behind it, the time running out said once", SpeakCapture.log,
     [[rea_mt(:rea_ppt_timeout), true], [rea_mt(:rea_ppt, :name => "Ataca", :hp => 160, :ehp => 180), false]]
  SpeakCapture.clear
  scene.instance_variable_set(:@frames, 0)
  scene.instance_variable_set(:@fase, 0)
  rm.ppt(scene)
  scene.instance_variable_set(:@frames, 60)
  rm.ppt(scene)
  spoke_once "the next round's choice running out is said again", /\A#{Regexp.escape(rea_mt(:rea_ppt_timeout))}\z/
end

Suite.define("realidea dance: each step shown, the player's turn, answers as hits or misses, and the grade") do
  rm = PokeAccess::RealideaMinigames
  score = ReaMiniSprite.new(false)
  scene = rea_mini_scene(:@direcciones => [], :@empezarcuenta => false, :@pausa => true, :@turno => 1,
                         :@playermov => 0, :@numaciertos => 0, :@score => "C", :@sprites => { "score" => score })
  rm.baile(scene)
  silent "the opening pause says nothing"

  scene.instance_variable_set(:@pausa, false)
  scene.instance_variable_set(:@empezarcuenta, true)
  scene.instance_variable_set(:@direcciones, ["Derecha"])
  rm.baile(scene)
  eq "the partner's first step as a direction", SpeakCapture.lines, [rea_mt(:dir_right)]
  scene.instance_variable_get(:@direcciones).push("Derecha")
  rm.baile(scene)
  eq "a repeated direction is a new step", SpeakCapture.lines, [rea_mt(:dir_right), rea_mt(:dir_right)]

  SpeakCapture.clear
  scene.instance_variable_set(:@empezarcuenta, false)
  rm.baile(scene)
  eq "the player's turn once the partner stops, queued", SpeakCapture.log, [[rea_mt(:rea_baile_turn), false]]

  SpeakCapture.clear
  scene.instance_variable_set(:@playermov, 1)
  scene.instance_variable_set(:@numaciertos, 1)
  rm.baile(scene)
  scene.instance_variable_set(:@playermov, 2)
  rm.baile(scene)
  eq "a hit with the count out of 22, a miss as a miss, and no direction", SpeakCapture.lines,
     [rea_mt(:rea_baile_hit, :n => 1, :tot => 22), rea_mt(:rea_baile_miss)]

  SpeakCapture.clear
  scene.instance_variable_set(:@score, "A")
  score.visible = true
  rm.baile(scene)
  rm.baile(scene)
  eq "the grade once its picture shows", SpeakCapture.lines, [rea_mt(:rea_baile_grade, :grade => "A")]
end

# PPT#update, Bailedoki#actu and Postresjuego#actu: each holds its scene for the per-frame reader while its loop runs,
# and lets it go as it ends.
Suite.define("realidea minigame loops: the reader follows each game while its loop runs, and lets go as it ends") do
  duel = rea_mini_game(PPT, :@steps => [{ :@selector => 0, :@fase => 0, :@comb => ["Agua", "Fuego", "Planta"],
                                          :@protahp => 180, :@enemhp => 180, :@tiempo2 => 60, :@frames => 0,
                                          :@sprites => {} }, { :@selector => 1 }])
  duel.update
  eq "the type duel: the focused type, the time a choice has, then the next type", SpeakCapture.lines,
     [rea_mt(:rea_ppt, :name => "Agua", :hp => 180, :ehp => 180), rea_mt(:rea_ppt_time, :t => "1,5 #{rea_mt(:secs, :n => 1.5)}"),
      rea_mt(:rea_ppt, :name => "Fuego", :hp => 180, :ehp => 180)]
  SpeakCapture.clear
  duel.instance_variable_set(:@selector, 2)
  Input.update
  silent "and nothing once its loop is over"

  SpeakCapture.clear
  dance = rea_mini_game(Bailedoki, :@steps => [{ :@direcciones => ["Derecha"], :@empezarcuenta => true, :@pausa => false,
                                                 :@turno => 1, :@playermov => 0, :@numaciertos => 0, :@score => "C",
                                                 :@sprites => { "score" => ReaMiniSprite.new(false) } },
                                               { :@empezarcuenta => false }])
  dance.actu
  eq "the dance: the partner's step, then the player's turn", SpeakCapture.lines,
     [rea_mt(:dir_right), rea_mt(:rea_baile_turn)]
  SpeakCapture.clear
  dance.instance_variable_set(:@numaciertos, 1)
  dance.instance_variable_set(:@playermov, 1)
  Input.update
  silent "and nothing once its loop is over"

  SpeakCapture.clear
  parfait = rea_mini_game(Postresjuego, :@steps => [{ :@cursor => 0, :@barra => 0 }, { :@barra => 150 }, { :@cursor => 2 }])
  parfait.actu
  eq "the parfait: the column, the bar as it fills, the next column", SpeakCapture.lines,
     [rea_mt(:rea_col, :n => 1), rea_mt(:rea_postre, :n => 0), rea_mt(:rea_postre, :n => 50), rea_mt(:rea_col, :n => 3)]
  SpeakCapture.clear
  parfait.instance_variable_set(:@barra, 300)
  Input.update
  silent "and nothing once its loop is over"
end

# Postresjuegobaya#actu and #input: the column and what falls in it while the loop runs, and each berry input catches
# as the next layer or as an empty glass; a finished parfait is the game's own message.
Suite.define("realidea berry parfait: what falls in the cursor's column, and each catch as a layer or an empty glass") do
  old = $Trainer
  begin
    tr = Object.new
    def tr.receta; ["Chesto", "Cheri", "Pecha"]; end
    $Trainer = tr
    recipe = rea_mt(:rea_baya_recipe, :recipe => "Atania, Zreza, Meloc")
    icons = {}
    5.times { |i| icons["icono#{i}"] = ReaMiniSprite.new(false, 115, -15, "Graphics/Pictures/Postregame/Safre") }
    icons["icono0"] = ReaMiniSprite.new(true, 115, 260, "Graphics/Pictures/Postregame/Chesto")
    icons["icono1"] = ReaMiniSprite.new(true, 115, 228, "Graphics/Pictures/Postregame/Rawst")
    game = rea_mini_game(Postresjuegobaya, :@cursor => 1, :@sprites => icons, :@ganado => false,
                         :@pisodefault0 => ["Atania", "Zreza", "Meloc"], :@pisodefault1 => [],
                         :@steps => [{}, { :@cursor => 0 }, {}, {}, {}, {}, {}, {}])
    game.actu
    eq "a column with nothing falling, then one with two berries, nearest first; a berry of the recipe caught is the " \
       "next layer, one out of it empties the glass", SpeakCapture.lines,
       ["#{rea_mt(:rea_col, :n => 2)}. #{recipe}",
        "#{rea_mt(:rea_col, :n => 1)}, #{rea_mt(:rea_baya_falling, :name => 'Atania, Safre')}. #{recipe}",
        rea_mt(:rea_baya_layer, :name => "Atania", :n => 1), rea_mt(:rea_baya_wrong, :name => "Safre")]

    SpeakCapture.clear
    icons["icono2"] = ReaMiniSprite.new(true, 115, 276, "Graphics/Pictures/Postregame/Pecha")
    last = rea_mini_game(Postresjuegobaya, :@cursor => 0, :@sprites => icons, :@ganado => false,
                         :@pisodefault0 => ["Atania", "Zreza", "Meloc"], :@pisodefault1 => ["Atania", "Zreza"],
                         :@steps => [{}, {}, {}])
    last.actu
    eq "a berry starting to fall in the cursor's column is said once, and the finished parfait is left to the game",
       SpeakCapture.lines, ["#{rea_mt(:rea_col, :n => 1)}, #{rea_mt(:rea_baya_falling, :name => 'Meloc')}. #{recipe}",
                            rea_mt(:rea_baya_falling, :name => "Meloc")]
    truthy "which the game has won", last.instance_variable_get(:@ganado)

    SpeakCapture.clear
    icons["icono3"].visible = true
    icons["icono3"].x = 115
    Input.update
    silent "and nothing once its loop is over"
  ensure
    $Trainer = old
  end
end
