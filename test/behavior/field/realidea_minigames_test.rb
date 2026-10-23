# Realidea's blocking-loop minigames (games/realidea/minigames.rb): the type duel, the dance and the two parfaits, read
# on plain scenes carrying the ivars each game keeps, and followed through each game's own loop on a stand-in.

# The type duel (Pelea tipos): update runs its blocking loop, one frame per entry of @steps, each leaving its ivar
# changes on the scene as the game's own frame work leaves them, then drawing and reading the input.
class PPT
  def update
    (@steps || []).each do |changes|
      changes.each { |k, v| instance_variable_set(k, v) }
      Graphics.update
      Input.update
    end
  end
end

# The dance (Bailedoki): actu runs its blocking loop, one frame per entry of @steps, as PPT#update does.
class Bailedoki
  def actu
    (@steps || []).each do |changes|
      changes.each { |k, v| instance_variable_set(k, v) }
      Graphics.update
      Input.update
    end
  end
end

# The parfait (Postresjuego): actu runs its blocking loop, one frame per entry of @steps, as PPT#update does.
class Postresjuego
  def actu
    (@steps || []).each do |changes|
      changes.each { |k, v| instance_variable_set(k, v) }
      Graphics.update
      Input.update
    end
  end
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
    (@steps || []).each do |changes|
      changes.each { |k, v| instance_variable_set(k, v) }
      Graphics.update
      Input.update
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

minigames = File.join(Harness::ROOT, "games", "realidea", "minigames.rb")
eval(Harness.source(minigames), TOPLEVEL_BINDING, minigames)

class RealideaMinigamesTest < PokeAccessTest
  Mini = PokeAccess::RealideaMinigames
  # A sprite as the readers see it: shown or not, where, and the picture it carries.
  Sprite = Struct.new(:visible, :x, :y, :name)
  # The type duel as a round opens: the selector on the first of three types, both sides at full HP, 60 frames a choice.
  DUEL = { :@selector => 0, :@fase => 0, :@comb => ["Agua", "Fuego", "Planta"], :@protahp => 180, :@enemhp => 180,
           :@tiempo2 => 60, :@frames => 0, :@sprites => {} }
  # The parfait's recipe as $Trainer.receta holds it, and as the example jars name its berries.
  RECIPE = ["Chesto", "Cheri", "Pecha"]
  JAR_NAMES = ["Atania", "Zreza", "Meloc"]

  test "opens the duel with the focused type and both HP, then the time each choice has, queued" do
    Mini.ppt(scene(DUEL))
    assert_equal [[t(:rea_ppt, :name => "Agua", :hp => 180, :ehp => 180), true], [t(:rea_ppt_time, :t => secs("1,5", 1.5)), false]],
                 SpeakCapture.log
  end

  test "says the type the selector moves to, again as either side's HP moves, and nothing while all stays" do
    duel = scene(DUEL)
    Mini.ppt(duel)
    SpeakCapture.clear
    duel.instance_variable_set(:@selector, 1)
    Mini.ppt(duel)
    duel.instance_variable_set(:@enemhp, 150)
    Mini.ppt(duel)
    Mini.ppt(duel)
    assert_equal [[t(:rea_ppt, :name => "Fuego", :hp => 180, :ehp => 180), true],
                  [t(:rea_ppt, :name => "Fuego", :hp => 180, :ehp => 150), true]], SpeakCapture.log
  end

  test "in the choosing phase and its resolution, says the button the selector is on" do
    [[2, 0, "Ataca"], [2, 1, "Defiende"], [3, 0, "Ataca"], [3, 1, "Defiende"]].each do |fase, sel, button|
      SpeakCapture.clear
      Mini.ppt(scene(DUEL.merge(:@fase => fase, :@selector => sel, :@tiempo2 => nil)))
      assert_equal [t(:rea_ppt, :name => button, :hp => 180, :ehp => 180)], SpeakCapture.lines, "phase #{fase}, selector #{sel}"
    end
  end

  test "says nothing for a selector off the types, on a blank one, or none at all" do
    [{ :@selector => 3 }, { :@selector => -1 }, { :@selector => nil }, { :@comb => nil },
     { :@comb => ["Agua", "", "Planta"], :@selector => 1 }].each do |change|
      Mini.ppt(scene(DUEL.merge(:@tiempo2 => nil).merge(change)))
    end
    assert_nothing_spoken
  end

  test "says each choice's time at the running frame rate" do
    [[60, 40, secs("1,5", 1.5)], [80, 40, secs("2", 2)], [60, 60, secs("1", 1)], [60, 1, secs("60", 60)],
     [60, 0, secs("1,5", 1.5)]].each do |frames, rate, time|
      SpeakCapture.clear
      with_frame_rate(rate) { Mini.ppt(scene(DUEL.merge(:@tiempo2 => frames, :@selector => nil))) }
      assert_equal [t(:rea_ppt_time, :t => time)], SpeakCapture.lines, "#{frames} frames at #{rate} a second"
    end
  end

  test "times a choice at 40 frames a second on an engine that cannot tell its rate" do
    with_frame_rate(nil) { Mini.ppt(scene(DUEL.merge(:@tiempo2 => 100, :@selector => nil))) }
    assert_equal [t(:rea_ppt_time, :t => secs("2,5", 2.5))], SpeakCapture.lines
  end

  test "says the rival's type once its icon slides in, once per round" do
    duel = scene(DUEL.merge(:@fase => 1, :@enemigo => "2", :@selector => nil, :@tiempo2 => nil,
                            :@sprites => { "Icon0" => Sprite.new(true), "Icon2" => Sprite.new(false) }))
    Mini.ppt(duel)
    assert_nothing_spoken "before the rival's icon is out"
    duel.instance_variable_get(:@sprites)["Icon2"].visible = true
    Mini.ppt(duel)
    Mini.ppt(duel)
    assert_equal [[t(:rea_ppt_rival, :name => "Planta"), true]], SpeakCapture.log
  end

  test "a new round with the same rival type says it again" do
    duel = scene(DUEL.merge(:@fase => 1, :@enemigo => "2", :@selector => nil, :@tiempo2 => nil,
                            :@sprites => { "Icon2" => Sprite.new(true) }))
    [1, 2, 1].each do |fase|
      duel.instance_variable_set(:@fase, fase)
      Mini.ppt(duel)
    end
    assert_equal [t(:rea_ppt_rival, :name => "Planta")] * 2, SpeakCapture.lines
  end

  test "says nothing of a rival with no type, no icon out or no type list" do
    unsure = Sprite.new(true)
    def unsure.visible; raise IOError, "disposed"; end
    shown = { "Icon2" => Sprite.new(true), "Icon5" => Sprite.new(true), "Icon0" => unsure }
    [{ :@enemigo => nil }, { :@enemigo => "1" }, { :@enemigo => "5" }, { :@enemigo => "2", :@comb => nil },
     { :@enemigo => "0" }].each do |change|
      Mini.ppt(scene(DUEL.merge(:@fase => 1, :@selector => nil, :@tiempo2 => nil, :@sprites => shown).merge(change)))
    end
    assert_nothing_spoken "nor of one whose icon cannot say whether it is out"
  end

  test "a choice that runs out says time's up, then the HP it cost, queued" do
    duel = scene(DUEL.merge(:@fase => 2, :@tiempo2 => 60))
    Mini.ppt(duel)
    SpeakCapture.clear
    duel.instance_variable_set(:@frames, 60)
    Mini.ppt(duel)
    duel.instance_variable_set(:@protahp, 160)
    Mini.ppt(duel)
    assert_equal [[t(:rea_ppt_timeout), true], [t(:rea_ppt, :name => "Ataca", :hp => 160, :ehp => 180), false]],
                 SpeakCapture.log, "time's up once"
  end

  test "the next round's choice running out is said again" do
    duel = scene(DUEL.merge(:@selector => nil))
    [60, 0, 60].each do |frames|
      duel.instance_variable_set(:@frames, frames)
      Mini.ppt(duel)
    end
    assert_equal [[t(:rea_ppt_timeout), true], [t(:rea_ppt_time, :t => secs("1,5", 1.5)), false], [t(:rea_ppt_timeout), true]],
                 SpeakCapture.log, "the round's @frames back to 0 re-arms it"
  end

  test "the opening pause of the dance says nothing" do
    Mini.baile(scene(dance))
    assert_nothing_spoken
  end

  test "says each step the partner shows as its direction, a repeated one as a new step" do
    steps = ["Derecha"]
    partner = scene(dance(:@pausa => false, :@empezarcuenta => true, :@direcciones => steps))
    Mini.baile(partner)
    steps.push("Derecha")
    Mini.baile(partner)
    Mini.baile(partner)
    assert_equal [[t(:dir_right), true], [t(:dir_right), true]], SpeakCapture.log
  end

  test "says a step the game names other than the four directions in the game's own word" do
    Mini.baile(scene(dance(:@pausa => false, :@empezarcuenta => true, :@direcciones => ["Giro"])))
    assert_equal [["Giro", true]], SpeakCapture.log
  end

  test "says the player's turn once the partner stops, queued, once per turn" do
    partner = scene(dance(:@pausa => false, :@direcciones => ["Arriba"]))
    [{}, {}, { :@numaciertos => 1, :@turno => 2, :@direcciones => [], :@pausa => true },
     { :@pausa => false, :@empezarcuenta => true, :@direcciones => ["Abajo"] }, { :@empezarcuenta => false }].each do |changes|
      changes.each { |k, v| partner.instance_variable_set(k, v) }
      Mini.baile(partner)
    end
    assert_equal [[t(:rea_baile_turn), false], [t(:rea_baile_hit, :n => 1, :tot => 22), true], [t(:dir_down), true],
                  [t(:rea_baile_turn), false]],
                 SpeakCapture.log, "the turn's last answer starts the next turn, whose partner dances before the player's turn"
  end

  test "says neither step nor turn from steps the partner is not dancing, nor a turn before any step" do
    Mini.baile(scene(dance(:@turno => 2, :@direcciones => ["Derecha"])))
    Mini.baile(scene(dance(:@pausa => false)))
    assert_nothing_spoken
  end

  test "says each answer as a hit with the running count, or as a miss" do
    player = scene(dance(:@pausa => true))
    Mini.baile(player)
    [[1, 1], [2, 1], [3, 2]].each do |mov, hits|
      player.instance_variable_set(:@playermov, mov)
      player.instance_variable_set(:@numaciertos, hits)
      Mini.baile(player)
    end
    assert_equal [[t(:rea_baile_hit, :n => 1, :tot => 22), true], [t(:rea_baile_miss), true],
                  [t(:rea_baile_hit, :n => 2, :tot => 22), true]], SpeakCapture.log, "out of the dance's 22 steps"
  end

  test "says the grade once its picture shows, interrupting" do
    score = Sprite.new(false)
    party = scene(dance(:@score => "A", :@sprites => { "score" => score }))
    Mini.baile(party)
    score.visible = true
    Mini.baile(party)
    Mini.baile(party)
    assert_equal [[t(:rea_baile_grade, :grade => "A"), true]], SpeakCapture.log
  end

  test "says no grade the picture shows blank, nor one whose picture cannot say whether it shows" do
    unsure = Sprite.new(true)
    def unsure.visible; raise IOError, "disposed"; end
    Mini.baile(scene(dance(:@score => "", :@sprites => { "score" => Sprite.new(true) })))
    Mini.baile(scene(dance(:@score => "A", :@sprites => { "score" => unsure })))
    assert_nothing_spoken
  end

  test "says the parfait's column under the cursor on every move, interrupting" do
    parfait = scene(:@cursor => 0)
    Mini.postres(parfait)
    Mini.postres(parfait)
    parfait.instance_variable_set(:@cursor, 2)
    Mini.postres(parfait)
    assert_equal [[t(:rea_col, :n => 1), true], [t(:rea_col, :n => 3), true]], SpeakCapture.log
  end

  test "says the parfait's bar as a percentage each time it fills, queued" do
    parfait = scene(:@barra => 0)
    [0, 150, 150, 300].each do |bar|
      parfait.instance_variable_set(:@barra, bar)
      Mini.postres(parfait)
    end
    assert_equal [[t(:rea_postre, :n => 0), false], [t(:rea_postre, :n => 50), false], [t(:rea_postre, :n => 100), false]],
                 SpeakCapture.log
  end

  test "names only the column's number while positions are left out" do
    said = lambda do |parfait|
      vb_levels do
        SpeakCapture.clear
        Mini.send(parfait[0], scene(parfait[1]))
        SpeakCapture.lines
      end
    end
    recipe = t(:rea_baya_recipe, :recipe => JAR_NAMES.join(", "))
    with_recipe(RECIPE) do
      assert_equal [[t(:rea_col_bare, :n => 2)], [t(:rea_col, :n => 2)], [t(:rea_col, :n => 2)]],
                   said.call([:postres, { :@cursor => 1 }]), "the parfait at brief, medium and full"
      assert_equal [["#{t(:rea_col_bare, :n => 1)}. #{recipe}"], ["#{t(:rea_col, :n => 1)}. #{recipe}"],
                    ["#{t(:rea_col, :n => 1)}. #{recipe}"]],
                   said.call([:postres_baya, { :@cursor => 0, :@sprites => berries }]), "the berry parfait"
    end
  end

  test "says the berry parfait's column with what falls in it, nearest the catch first, and the recipe" do
    icons = berries("icono0" => Sprite.new(true, 115, 260, picture("Chesto")),
                    "icono1" => Sprite.new(true, 115, 228, picture("Rawst")),
                    "icono2" => Sprite.new(true, 210, 300, picture("Pecha")))
    parfait = scene(:@cursor => 2, :@sprites => icons)
    with_recipe(RECIPE) do
      [2, 0, 1].each do |cur|
        parfait.instance_variable_set(:@cursor, cur)
        Mini.postres_baya(parfait)
      end
    end
    recipe = t(:rea_baya_recipe, :recipe => JAR_NAMES.join(", "))
    assert_equal [["#{t(:rea_col, :n => 3)}. #{recipe}", true],
                  ["#{t(:rea_col, :n => 1)}, #{t(:rea_baya_falling, :name => 'Atania, Safre')}. #{recipe}", true],
                  ["#{t(:rea_col, :n => 2)}, #{t(:rea_baya_falling, :name => 'Meloc')}. #{recipe}", true]],
                 SpeakCapture.log, "berries already falling as the cursor arrives are in its column's line alone"
  end

  test "says each berry that starts falling in the cursor's column, once each time it shows" do
    icons = berries
    parfait = scene(:@cursor => 2, :@sprites => icons)
    with_recipe(RECIPE) do
      Mini.postres_baya(parfait)
      SpeakCapture.clear
      icons["icono0"] = Sprite.new(true, 305, -15, picture("Pecha"))
      icons["icono4"] = Sprite.new(true, 115, -15, picture("Cheri"))
      Mini.postres_baya(parfait)
      Mini.postres_baya(parfait)
      icons["icono0"].visible = false
      Mini.postres_baya(parfait)
      icons["icono0"].visible = true
      Mini.postres_baya(parfait)
    end
    assert_equal [[t(:rea_baya_falling, :name => "Meloc"), true]] * 2, SpeakCapture.log, "not the berry in another column"
  end

  test "takes a berry sprite that fails to say whether it shows for a hidden one" do
    broken = Sprite.new(true, 115, 250, picture("Pecha"))
    def broken.visible; raise IOError, "disposed"; end
    with_recipe(RECIPE) { Mini.postres_baya(scene(:@cursor => 0, :@sprites => berries("icono0" => broken))) }
    assert_equal ["#{t(:rea_col, :n => 1)}. #{t(:rea_baya_recipe, :recipe => JAR_NAMES.join(', '))}"], SpeakCapture.lines
  end

  test "says nothing of a berry parfait with no cursor" do
    with_recipe(RECIPE) { Mini.postres_baya(scene(:@cursor => nil, :@sprites => berries)) }
    assert_nothing_spoken
  end

  test "names the recipe's berries as the example jars do, and any other by its own name" do
    with_recipe(["Rawst", "Oran"]) do
      assert_equal "Safre, Oran", Mini.recipe_text
    end
  end

  test "names no recipe while the trainer keeps none" do
    keeps_none = with_recipe(nil) { Mini.recipe_text }
    lacks_one = with_trainer(Object.new) { Mini.recipe_text }
    assert_equal ["", ""], [keeps_none, lacks_one], "a recipe of nil, and a trainer with no recipe at all"
  end

  test "says a caught berry of the recipe as the glass's next layer" do
    [[[], "Chesto", "Atania", 1], [["Atania"], "Cheri", "Zreza", 2]].each do |layers, berry, name, n|
      SpeakCapture.clear
      with_recipe(RECIPE) { catch_berry(berry, layers) }
      assert_equal moved_under(name) + [[t(:rea_baya_layer, :name => name, :n => n), true]], SpeakCapture.log,
                   "#{name} on a glass of #{layers.inspect}"
    end
  end

  test "says a caught berry out of the recipe as the glass emptied" do
    with_recipe(RECIPE) { catch_berry("Rawst", ["Atania"]) }
    assert_equal moved_under("Safre") + [[t(:rea_baya_wrong, :name => "Safre"), true]], SpeakCapture.log
  end

  test "leaves the finished parfait to the game's own message" do
    with_recipe(RECIPE) { catch_berry("Pecha", ["Atania", "Zreza"]) }
    assert_equal moved_under("Meloc"), SpeakCapture.log, "the third berry of the recipe completes it"
  end

  test "says a caught berry as the glass emptied when the game keeps no glass" do
    Mini.baya_caught(scene(:@sprites => berries, :@pisodefault1 => nil), [0])
    assert_equal [[t(:rea_baya_wrong, :name => "Safre"), true]], SpeakCapture.log
  end

  test "takes a berry sprite that fails to say whether it still shows after the input for one not caught" do
    gone = Sprite.new(true, 115, 300, picture("Pecha"))
    def gone.visible; raise IOError, "disposed"; end
    Mini.baya_caught(scene(:@sprites => berries("icono0" => gone), :@pisodefault1 => ["Atania"]), [0])
    assert_nothing_spoken
  end

  test "follows the berry parfait while its loop runs and lets it go as it ends" do
    with_recipe(RECIPE) do
      parfait = play_baya(berries, [], [{}, { :@cursor => 1 }])
      lines = SpeakCapture.lines.dup
      SpeakCapture.clear
      parfait.instance_variable_set(:@cursor, 2)
      Input.update
      recipe = t(:rea_baya_recipe, :recipe => JAR_NAMES.join(", "))
      assert_equal ["#{t(:rea_col, :n => 1)}. #{recipe}", "#{t(:rea_col, :n => 2)}. #{recipe}"], lines
    end
    assert_nothing_spoken "once its loop is over"
  end

  test "follows the type duel while its loop runs and lets it go as it ends" do
    duel = game(PPT, :@steps => [DUEL, { :@selector => 1 }])
    duel.update
    lines = SpeakCapture.lines.dup
    SpeakCapture.clear
    duel.instance_variable_set(:@selector, 2)
    Input.update
    assert_equal [t(:rea_ppt, :name => "Agua", :hp => 180, :ehp => 180), t(:rea_ppt_time, :t => secs("1,5", 1.5)),
                  t(:rea_ppt, :name => "Fuego", :hp => 180, :ehp => 180)], lines
    assert_nothing_spoken "once its loop is over"
  end

  test "lets a duel whose loop fails go" do
    duel = game(PPT, :@steps => [DUEL, nil])
    assert_raises(NoMethodError) { duel.update }
    SpeakCapture.clear
    duel.instance_variable_set(:@selector, 2)
    Input.update
    assert_nothing_spoken
  end

  test "follows the dance while its loop runs and lets it go as it ends" do
    partner = game(Bailedoki, :@steps => [dance(:@pausa => false, :@empezarcuenta => true, :@direcciones => ["Derecha"]),
                                          { :@empezarcuenta => false }])
    partner.actu
    lines = SpeakCapture.lines.dup
    SpeakCapture.clear
    partner.instance_variable_set(:@playermov, 1)
    partner.instance_variable_set(:@numaciertos, 1)
    Input.update
    assert_equal [t(:dir_right), t(:rea_baile_turn)], lines
    assert_nothing_spoken "once its loop is over"
  end

  test "follows the parfait while its loop runs and lets it go as it ends" do
    parfait = game(Postresjuego, :@steps => [{ :@cursor => 0, :@barra => 0 }, { :@barra => 150 }, { :@cursor => 2 }])
    parfait.actu
    lines = SpeakCapture.lines.dup
    SpeakCapture.clear
    parfait.instance_variable_set(:@barra, 300)
    Input.update
    assert_equal [t(:rea_col, :n => 1), t(:rea_postre, :n => 0), t(:rea_postre, :n => 50), t(:rea_col, :n => 3)], lines
    assert_nothing_spoken "once its loop is over"
  end

  private

  # The text of key in the running language.
  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # A time as the duel says it: the number as written, then the unit for n.
  def secs(number, n)
    "#{number} #{t(:secs, :n => n)}"
  end

  # A plain scene carrying these ivars, as the game's scene carries them.
  def scene(ivars)
    s = Object.new
    ivars.each { |k, v| s.instance_variable_set(k, v) }
    s
  end

  # One of the minigames with these ivars, built without its initializer (which runs the whole loop).
  def game(klass, ivars)
    g = klass.allocate
    ivars.each { |k, v| g.instance_variable_set(k, v) }
    g
  end

  # The dance's ivars in its opening pause (turn 1, no step shown, no answer, grade C hidden), with changes.
  def dance(changes = {})
    { :@direcciones => [], :@empezarcuenta => false, :@pausa => true, :@turno => 1, :@playermov => 0,
      :@numaciertos => 0, :@score => "C", :@sprites => { "score" => Sprite.new(false) } }.merge(changes)
  end

  # The berry parfait's five falling sprites, all hidden at the top of the first column unless given.
  def berries(given = {})
    icons = {}
    5.times { |i| icons["icono#{i}"] = Sprite.new(false, 115, -15, picture("Safre")) }
    icons.merge(given)
  end

  # A berry's picture path.
  def picture(berry)
    "Graphics/Pictures/Postregame/#{berry}"
  end

  # Runs the block with $Trainer holding this recipe, the game's trainer put back afterwards.
  def with_recipe(recipe, &blk)
    trainer = Object.new
    trainer.define_singleton_method(:receta) { recipe }
    with_trainer(trainer, &blk)
  end

  # Runs the block with trainer as $Trainer, the game's put back afterwards.
  def with_trainer(trainer)
    was = $Trainer
    $Trainer = trainer
    yield
  ensure
    $Trainer = was
  end

  # Runs Graphics.frame_rate at rate through the block, or for nil failing as on an engine without one; the engine's
  # own put back afterwards.
  def with_frame_rate(rate)
    sc = Graphics.singleton_class
    sc.send(:alias_method, :pa_rea_mini_frame_rate, :frame_rate)
    sc.send(:define_method, :frame_rate) { rate || raise(NoMethodError, "undefined method 'frame_rate' for Graphics") }
    yield
  ensure
    sc.send(:alias_method, :frame_rate, :pa_rea_mini_frame_rate)
    sc.send(:remove_method, :pa_rea_mini_frame_rate)
  end

  # Plays the berry parfait over steps with the cursor on the first column, the glass holding layers of the recipe, and
  # these sprites; returns the game.
  def play_baya(icons, layers, steps)
    parfait = game(Postresjuegobaya, :@cursor => 0, :@sprites => icons, :@ganado => false,
                   :@pisodefault0 => JAR_NAMES.dup, :@pisodefault1 => layers.dup, :@steps => steps)
    parfait.actu
    parfait
  end

  # Plays two frames of the berry parfait with berry falling over the first column, just above the glass: in the first
  # the cursor is on the second column and the berry falls into reach, in the second the cursor moves under it and the
  # input catches it.
  def catch_berry(berry, layers)
    play_baya(berries("icono0" => Sprite.new(true, 115, 276, picture(berry))), layers, [{ :@cursor => 1 }, { :@cursor => 0 }])
  end

  # What catch_berry's moves say: the second column, then the first with the berry called name falling in it.
  def moved_under(name)
    recipe = t(:rea_baya_recipe, :recipe => JAR_NAMES.join(", "))
    [["#{t(:rea_col, :n => 2)}. #{recipe}", true],
     ["#{t(:rea_col, :n => 1)}, #{t(:rea_baya_falling, :name => name)}. #{recipe}", true]]
  end
end
