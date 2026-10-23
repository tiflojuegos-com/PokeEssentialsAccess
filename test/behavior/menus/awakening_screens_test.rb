# Awakening's own screens through the profile's hooks, on stand-ins of its classes defined before the files load: the
# class picker, the compendium, the EV redistributor, tea time, PsyduckHunt, the Critical Quotes and Kyu's autosave.

module Fates_Utilities
  def self.checkIfHasClass(_who, cls); cls != "Ladrón"; end
end

# Fates_Menu_Personajes, whose loop runs inside initialize: the class list (@classArray), the focus (@select) and the
# detail panel (@sprites["Base"]). One frame as it opens, then one per step: a cursor move (the index it lands on),
# :panel (the detail panel shown or hidden), [:lore, title, text] (the lore window, run in its own loop) or :peek (the
# info key as that frame leaves it, kept in #peeked).
class Fates_Menu_Personajes
  TIMESKIPSWITCH = 468
  TIMESKIP = { "Aldeano" => "Elegido" }
  TEXTOS = { "Lana" => { "Elegido" => "La elegida por el universo.", "Aldeano" => "Pueblerina valiente.",
                         "Aprendiz" => "Principiante en la magia." } }
  HABS = { "Lana" => { "Aldeano" => "Ninguna.", "Aprendiz" => ">Miscelánea." } }

  attr_reader :peeked

  def initialize(sel = 0, steps = [], classes = ["Aldeano", "Aprendiz", "Ladrón"])
    @name = "Lana"
    @classArray = classes
    @select = sel
    @sprites = { "Base" => Struct.new(:visible).new(false) }
    PokeAccess::Frame.run_pollers
    steps.each do |step|
      if step == :panel
        @sprites["Base"].visible = !@sprites["Base"].visible
      elsif step == :peek
        @peeked = PokeAccess::Info.info_text
      elsif step.is_a?(Array)
        showLoreWindow(step[1], step[2])
      else
        @select = step
      end
      PokeAccess::Frame.run_pollers
    end
  end

  def habs2_text(nombre, clase, nivel); "Senda de #{clase} para #{nombre}\nNivel #{nivel}."; end
  def showLoreWindow(_title, _text); :lore_closed; end
end

# ListaAngeles, one of the compendium's viewers: each frame paints every row's name (drawTextEx) and runs update over
# the focus (@select in @opciones, each with .nombre); pbDatosAngel paints an entry's sheet and runs two frames of its
# own loop.
class ListaAngeles
  def initialize(rows); @select = 0; @opciones = rows; end

  def update
    @opciones.each { |row| drawTextEx(nil, 70, 0, 312, 2, row.nombre) }
    :updated
  end

  def pbDatosAngel(num)
    pbDrawTextPositions(nil, [[@opciones[num].nombre, 260, 38, 0], ["Obtenido", 14, 40, 0],
                              ["X = Volver", 290, 358, 0]])
    drawTextEx(nil, 0, 4, 258, 5, "Guardián de la luz.")
    2.times { PokeAccess::Frame.run_pollers }
    :sheet_closed
  end
end

# The "more information" panel the compendium's sheets open.
def carteles(_x, _y, _text); :shown; end

# EVReorganizeScene with its own cost rule (500 a point added) and its two highest base stats, Attack and Sp. Atk.
class EVReorganizeScene
  STAT_ORDER = [0, 1, 2, 4, 5, 3]

  def initialize(pokemon, evs, ivs = [31] * 6)
    @pokemon = pokemon
    @original_evs = evs.dup
    @current_evs = evs
    @ivs = ivs
    @max_evs = evs.inject(0) { |s, e| s + e }
    @selected_stat = 0
  end

  def drawScreen; :drawn; end
  def getTopTwoStats; [1, 4]; end

  def calculateCost
    cost = 0
    6.times { |i| d = @current_evs[i] - @original_evs[i]; cost += d * 500 if d > 0 }
    cost
  end
end

class Scene_HoraDelTe
  def initialize(name); @personaje_nombre = name; end
  def observar_personaje; :observed; end
end

# PsyduckHunt, whose pbUpdate is BaseMinigame's loop: a frame as the round stands, then one per entry of frames, each
# setting first the round's ivars it names.
class PsyduckHunt
  def initialize(frames = [])
    @score = 0; @hits = 0; @pause = false; @framesLeft = 300; @totalFrames = 300
    @frames = frames
  end

  def pbUpdate
    PokeAccess::Frame.run_pollers
    @frames.each do |frame|
      frame.each { |ivar, value| instance_variable_set(ivar, value) }
      PokeAccess::Frame.run_pollers
    end
    :round_over
  end
end

# Critical_Quotes, the finishing blow's cut-in: its initialize draws the quote with Bitmap#draw_text, by position and
# by rect.
class Critical_Quotes
  def initialize(_mugshot)
    Bitmap.new.draw_text(0, 0, 512, 384, "Podrías hacerlo mejor, hermana.", 1)
    Bitmap.new.draw_text(Object.new, "Segunda linea.")
  end
end

# Kyu's autosave animation, a top-level function.
def autosaveAnim; :slid; end

%w[games/awakening/outfits games/awakening/compendium games/awakening/extras games/awakening/tea_time
   games/awakening/psyduck_hunt games/awakening/quotes plugins/kyu_autosave].each do |file|
  path = File.join(Harness::ROOT, "#{file}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class AwakeningScreensTest < PokeAccessTest
  T = PokeAccess::I18n
  LEVELS = { "Lana" => { "Aldeano" => 2, "Aprendiz" => 1 } }
  Angel = Struct.new(:nombre)
  EvMon = Struct.new(:totalhp, :attack, :defense, :speed, :spatk, :spdef, :nature, :shadow, :heartStage) do
    def isShadow?; shadow ? true : false; end
  end

  test "the class picker says a locked class as its picture paints it, with no name, queued as it opens" do
    with_class_levels { Fates_Menu_Personajes.new(2) }
    assert_equal [[T.t(:aw_outfit_locked), false]], SpeakCapture.log
  end

  test "the class picker says an unlocked class's name, level and ability, and in full its description" do
    with_class_levels { Fates_Menu_Personajes.new(1) }
    assert_equal [["#{apprentice} Principiante en la magia.", false]], SpeakCapture.log
  end

  test "the class picker says the class the cursor moves to" do
    with_class_levels { Fates_Menu_Personajes.new(2, [1]) }
    assert_equal [[T.t(:aw_outfit_locked), false], ["#{apprentice} Principiante en la magia.", true]],
                 SpeakCapture.log
  end

  test "the class picker says nothing more on a frame with the cursor still" do
    with_class_levels { Fates_Menu_Personajes.new(1, [1]) }
    assert_equal [["#{apprentice} Principiante en la magia.", false]], SpeakCapture.log
  end

  test "the class picker leaves the description below full on the info key, which keeps the whole line" do
    PokeAccess::Config.verbosity = :medium
    picker = with_class_levels { Fates_Menu_Personajes.new(1, [:peek]) }
    assert_equal [[apprentice, false]], SpeakCapture.log
    assert_equal "#{apprentice} Principiante en la magia.", picker.peeked
  end

  test "the class picker takes the class line off the info key as it closes" do
    with_class_levels { Fates_Menu_Personajes.new(1) }
    assert_nil PokeAccess::Info.info_text
  end

  test "the class picker reads the detail panel by its own text while it is up, and the class once it is hidden" do
    with_class_levels { Fates_Menu_Personajes.new(1, [:panel, :panel]) }
    line = "#{apprentice} Principiante en la magia."
    assert_equal [[line, false], ["Senda de Aprendiz para Lana Nivel 1.", true], [line, true]], SpeakCapture.log
  end

  test "after the time skip, a class is said by its new name, its level and ability kept from the one listed" do
    $game_switches[468] = true
    with_class_levels { Fates_Menu_Personajes.new(0) }
    line = "Elegido, #{T.t(:awk_class_level, :n => 2)}, #{T.t(:awk_class_ability, :name => 'Ninguna.')} " \
           "La elegida por el universo."
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "after the time skip, the detail panel takes the level kept under the class's new name, 0 where none is" do
    $game_switches[468] = true
    with_class_levels { Fates_Menu_Personajes.new(0, [:panel]) }
    assert_equal ["Senda de Elegido para Lana Nivel 0.", true], SpeakCapture.log.last
  end

  test "the class picker's lore window says its title and lore, and the class again once it closes" do
    with_class_levels { Fates_Menu_Personajes.new(1, [[:lore, "Aprendiz", "Nacida de los libros."]]) }
    line = "#{apprentice} Principiante en la magia."
    assert_equal [[line, false], ["#{T.t(:awk_class_lore, :name => 'Aprendiz')}. Nacida de los libros.", true],
                  [line, true]], SpeakCapture.log
  end

  test "the class picker leaves out the level and the ability the game holds none for" do
    with_class_levels("Lana" => {}) { Fates_Menu_Personajes.new(0, [], ["Aldeano", "Pastora"]) }
    with_class_levels("Lana" => { "Pastora" => 3 }) { Fates_Menu_Personajes.new(1, [], ["Aldeano", "Pastora"]) }
    assert_equal [["Aldeano, #{T.t(:awk_class_ability, :name => 'Ninguna.')} Pueblerina valiente.", false],
                  ["Pastora, #{T.t(:awk_class_level, :n => 3)}", false]], SpeakCapture.log
  end

  test "the class picker says nothing for a cursor past its list or on a class with no name" do
    with_class_levels { Fates_Menu_Personajes.new(3) }
    with_class_levels { Fates_Menu_Personajes.new(0, [], [""]) }
    assert_nothing_spoken
  end

  test "a compendium list says its focused entry with its place" do
    ListaAngeles.new(angels).update
    assert_equal [[T.t(:list_entry, :name => "Miguel", :n => 1, :tot => 2), true]], SpeakCapture.log
  end

  test "a compendium list says an entry once while the cursor stays on it" do
    list = ListaAngeles.new(angels)
    list.update
    SpeakCapture.clear
    list.update
    assert_nothing_spoken
  end

  test "a compendium list reads an entry it has not registered yet as locked" do
    list = ListaAngeles.new([Angel.new("Miguel"), Angel.new("¿¿??")])
    list.instance_variable_set(:@select, 1)
    list.update
    assert_equal [[T.t(:list_entry, :name => T.t(:awk_glos_locked), :n => 2, :tot => 2), true]], SpeakCapture.log
  end

  test "a compendium sheet says what it paints, once, as its loop runs" do
    ListaAngeles.new(angels).pbDatosAngel(0)
    assert_equal [["Miguel. Obtenido. X = Volver. Guardián de la luz.", true]], SpeakCapture.log
  end

  test "a closed compendium sheet leaves its list to say the focus again" do
    list = ListaAngeles.new(angels)
    list.update
    list.pbDatosAngel(0)
    SpeakCapture.clear
    list.update
    assert_equal [[T.t(:list_entry, :name => "Miguel", :n => 1, :tot => 2), true]], SpeakCapture.log
  end

  test "the compendium's more-information panel says its text" do
    carteles(440, 14, "Datos completos.")
    assert_equal [["Datos completos.", true]], SpeakCapture.log
  end

  test "the EV screen says each stat's row as painted: value, EV and IV, the nature's tint and the recommended mark" do
    screen = ev_screen
    rows = { 0 => T.t(:awk_ev_row, :name => "Estadistica0", :value => 200, :ev => 4, :iv => 31),
             1 => [T.t(:awk_ev_row, :name => "Estadistica1", :value => 150, :ev => 12, :iv => 31),
                   T.t(:awk_ev_nat_up), T.t(:awk_ev_recommended)].join(", "),
             2 => "#{T.t(:awk_ev_row, :name => 'Estadistica2', :value => 90, :ev => 0, :iv => 31)}, " \
                  "#{T.t(:awk_ev_nat_down)}",
             3 => "#{T.t(:awk_ev_row, :name => 'Estadistica4', :value => 70, :ev => 0, :iv => 31)}, " \
                  "#{T.t(:awk_ev_recommended)}",
             5 => T.t(:awk_ev_row, :name => "Estadistica3", :value => 80, :ev => 0, :iv => 31) }
    rows.each do |row, line|
      SpeakCapture.clear
      screen.instance_variable_set(:@selected_stat, row)
      screen.drawScreen
      assert_equal [[line, true]], SpeakCapture.log, "row #{row}"
    end
  end

  test "the EV screen says nothing on a redraw with nothing changed" do
    screen = ev_screen
    screen.drawScreen
    SpeakCapture.clear
    screen.drawScreen
    assert_nothing_spoken
  end

  test "the EV screen says a step down on its row as the EVs, the new value, what is left and the cost" do
    mon = ev_mon
    screen = ev_screen(mon)
    screen.instance_variable_set(:@selected_stat, 1)
    screen.drawScreen
    SpeakCapture.clear
    screen.instance_variable_get(:@current_evs)[1] = 11
    mon.attack = 149
    screen.drawScreen
    line = "#{T.t(:awk_ev_change, :ev => 11, :name => 'Estadistica1', :value => 149)}. " \
           "#{T.t(:awk_ev_left, :n => 1)}. #{T.t(:awk_ev_cost, :n => 0)}"
    assert_equal [[line, true]], SpeakCapture.log
  end

  test "the EV screen warns of a cost past the money held, and not of one the money covers" do
    { 300 => ", #{T.t(:awk_ev_short)}", 500 => "" }.each do |money, warning|
      with_money(money) do
        SpeakCapture.clear
        point_added
        line = "#{T.t(:awk_ev_change, :ev => 1, :name => 'Estadistica4', :value => 71)}. " \
               "#{T.t(:awk_ev_left, :n => 0)}. #{T.t(:awk_ev_cost, :n => 500)}#{warning}"
        assert_equal [[line, true]], SpeakCapture.log, "with #{money} held"
      end
    end
  end

  test "the EV screen's Confirm row says the totals, what is left and the cost" do
    with_money(300) do
      screen = point_added
      SpeakCapture.clear
      screen.instance_variable_set(:@selected_stat, 6)
      screen.drawScreen
    end
    line = "#{T.t(:pc_confirm)}. #{T.t(:awk_ev_totals, :n => 16, :max => 16)}. #{T.t(:awk_ev_left, :n => 0)}. " \
           "#{T.t(:awk_ev_cost, :n => 500)}, #{T.t(:awk_ev_short)}"
    assert_equal [[line, true]], SpeakCapture.log
  end

  test "the EV screen reads a row without the IV the screen does not hold" do
    EVReorganizeScene.new(ev_mon, [4, 12, 0, 0, 0, 0], nil).drawScreen
    assert_equal [[T.t(:awk_ev_row_noiv, :name => "Estadistica0", :value => 200, :ev => 4), true]], SpeakCapture.log
  end

  test "the EV screen tints no name for a neutral nature, one it cannot number, or a shadow past heart stage 3" do
    { [6, false, 0] => "", [:ADAMANT, false, 0] => "", [7, true, 4] => "",
      [7, true, 3] => ", #{T.t(:awk_ev_nat_up)}" }.each do |(nature, shadow, stage), tint|
      SpeakCapture.clear
      screen = ev_screen(EvMon.new(200, 150, 90, 80, 70, 60, nature, shadow, stage))
      screen.instance_variable_set(:@selected_stat, 1)
      screen.drawScreen
      line = "#{T.t(:awk_ev_row, :name => 'Estadistica1', :value => 150, :ev => 12, :iv => 31)}#{tint}, " \
             "#{T.t(:awk_ev_recommended)}"
      assert_equal [[line, true]], SpeakCapture.log, "nature #{nature}, shadow #{shadow}, heart stage #{stage}"
    end
  end

  test "the EV screen names a stat the data has no name for by its number" do
    data = PokeAccess::Data
    real = data.method(:stat_name)
    data.define_singleton_method(:stat_name) { |s| s == 0 ? "" : real.call(s) }
    begin
      ev_screen.drawScreen
    ensure
      data.define_singleton_method(:stat_name, real)
    end
    assert_equal [[T.t(:awk_ev_row, :name => "0", :value => 200, :ev => 4, :iv => 31), true]], SpeakCapture.log
  end

  test "tea time's Observe says whom, with the keys that move the picture and leave" do
    Scene_HoraDelTe.new("Holly").observar_personaje
    assert_equal [["#{T.t(:awk_observe, :name => 'Holly')}. #{T.t(:awk_observe_keys)}", true]], SpeakCapture.log
  end

  test "tea time's Observe says whom alone with hints off" do
    PokeAccess::Config.verbosity = :brief
    Scene_HoraDelTe.new("Holly").observar_personaje
    assert_equal [[T.t(:awk_observe, :name => "Holly"), true]], SpeakCapture.log
  end

  test "tea time's Observe with no one named says the bare line" do
    Scene_HoraDelTe.new("").observar_personaje
    assert_equal [["#{T.t(:awk_observe_bare)}. #{T.t(:awk_observe_keys)}", true]], SpeakCapture.log
  end

  test "a PsyduckHunt round says each hit with the score, then the final score as it ends, queued" do
    PsyduckHunt.new([{ :@score => 500, :@hits => 1 }]).pbUpdate
    assert_equal [[T.t(:awk_duck_score, :n => 500, :hits => 1), true], [T.t(:awk_duck_final, :n => 500), false]],
                 SpeakCapture.log
  end

  test "PsyduckHunt says the pause with the key that quits, and the resume" do
    PsyduckHunt.new([{ :@pause => true }, { :@pause => false }]).pbUpdate
    assert_equal [["#{T.t(:awk_duck_pause)}. #{T.t(:awk_duck_quit_key)}", true], [T.t(:awk_duck_resume), true],
                  [T.t(:awk_duck_final, :n => 0), false]], SpeakCapture.log
  end

  test "PsyduckHunt says the pause alone with hints off" do
    PokeAccess::Config.verbosity = :brief
    PsyduckHunt.new([{ :@pause => true }]).pbUpdate
    assert_equal [[T.t(:awk_duck_pause), true], [T.t(:awk_duck_final, :n => 0), false]], SpeakCapture.log
  end

  test "PsyduckHunt says the hits alone when a miss drops them" do
    PsyduckHunt.new([{ :@score => 300, :@hits => 3 }, { :@hits => 0 }]).pbUpdate
    assert_equal [[T.t(:awk_duck_score, :n => 300, :hits => 3), true], [T.t(:awk_duck_hits, :n => 0), true],
                  [T.t(:awk_duck_final, :n => 300), false]], SpeakCapture.log
  end

  test "PsyduckHunt says a resume and a miss of the same frame in one line" do
    PsyduckHunt.new([{ :@score => 300, :@hits => 3 }, { :@pause => true }, { :@pause => false, :@hits => 0 }]).pbUpdate
    assert_equal [[T.t(:awk_duck_score, :n => 300, :hits => 3), true],
                  ["#{T.t(:awk_duck_pause)}. #{T.t(:awk_duck_quit_key)}", true],
                  ["#{T.t(:awk_duck_resume)}. #{T.t(:awk_duck_hits, :n => 0)}", true],
                  [T.t(:awk_duck_final, :n => 300), false]], SpeakCapture.log
  end

  test "PsyduckHunt says the time bar crossing each mark once, and nothing until the next" do
    PsyduckHunt.new([225, 150, 75, 74, 30].map { |left| { :@framesLeft => left } }).pbUpdate
    marks = [75, 50, 25, 10].map { |n| [T.t(:awk_duck_time, :n => n), true] }
    assert_equal marks + [[T.t(:awk_duck_final, :n => 0), false]], SpeakCapture.log
  end

  test "PsyduckHunt says the changes of one frame in one line: the pause, the score, then the time" do
    PsyduckHunt.new([{ :@pause => true, :@score => 500, :@hits => 1, :@framesLeft => 30 }]).pbUpdate
    line = ["#{T.t(:awk_duck_pause)}. #{T.t(:awk_duck_quit_key)}", T.t(:awk_duck_score, :n => 500, :hits => 1),
            T.t(:awk_duck_time, :n => 10)].join(". ")
    assert_equal [[line, true], [T.t(:awk_duck_final, :n => 500), false]], SpeakCapture.log
  end

  test "PsyduckHunt says no time mark for a round with no length, and still says its score" do
    PsyduckHunt.new([{ :@totalFrames => 0, :@framesLeft => 0 }, { :@score => 100, :@hits => 1 }]).pbUpdate
    assert_equal [[T.t(:awk_duck_score, :n => 100, :hits => 1), true], [T.t(:awk_duck_final, :n => 100), false]],
                 SpeakCapture.log
  end

  test "Kyu's autosave says the green star that slides in on a map change, queued" do
    autosaveAnim
    assert_equal [[T.t(:kyu_autosaved), false]], SpeakCapture.log
  end

  test "the Critical Quotes cut-in says each line it draws, queued" do
    with_bitmap { Critical_Quotes.new("Liam") }
    assert_equal [["Podrías hacerlo mejor, hermana.", false], ["Segunda linea.", false]], SpeakCapture.log
  end

  test "after the Critical Quotes cut-in, draw_text is the game's own again and says nothing" do
    with_bitmap do
      Critical_Quotes.new("Liam")
      SpeakCapture.clear
      assert_equal :drawn, Bitmap.new.draw_text(0, 0, 10, 10, "Hola")
    end
    assert_nothing_spoken
  end

  test "the hooked methods return what the game's own return" do
    list = ListaAngeles.new(angels)
    { [Fates_Menu_Personajes.new(1), [:showLoreWindow, "Aprendiz", "Libros."]] => :lore_closed,
      [ev_screen, [:drawScreen]] => :drawn, [Scene_HoraDelTe.new("Holly"), [:observar_personaje]] => :observed,
      [PsyduckHunt.new, [:pbUpdate]] => :round_over, [list, [:update]] => :updated,
      [list, [:pbDatosAngel, 0]] => :sheet_closed, [self, [:autosaveAnim]] => :slid,
      [self, [:carteles, 440, 14, "Datos."]] => :shown }.each do |(obj, call), value|
      assert_equal value, obj.send(*call), "#{obj.class}##{call[0]}"
    end
  end

  private

  # Runs the block with the player's class levels as Awakening keeps them, the method removed after; its value.
  def with_class_levels(levels = LEVELS)
    meta = $game_player.singleton_class
    meta.send(:define_method, :clases) { levels }
    yield
  ensure
    meta.send(:remove_method, :clases)
  end

  # The apprentice's class line before its description: its name, level and ability as the picker paints them.
  def apprentice
    "Aprendiz, #{T.t(:awk_class_level, :n => 1)}, #{T.t(:awk_class_ability, :name => 'Miscelánea.')}"
  end

  # The compendium's two angels.
  def angels
    [Angel.new("Miguel"), Angel.new("Rafael")]
  end

  # A Pokemon whose nature (7) raises the stat drawScreen numbers 1 (Attack) and lowers 2 (Defense).
  def ev_mon
    EvMon.new(200, 150, 90, 80, 70, 60, 7, false, 0)
  end

  # The EV screen over mon with 4 EVs on HP and 12 on Attack, on its first row.
  def ev_screen(mon = ev_mon)
    EVReorganizeScene.new(mon, [4, 12, 0, 0, 0, 0])
  end

  # The EV screen with a point moved from Attack to Sp. Atk (row 3), drawn on that row before and after; the screen.
  def point_added
    mon = ev_mon
    screen = ev_screen(mon)
    screen.instance_variable_set(:@selected_stat, 3)
    screen.drawScreen
    SpeakCapture.clear
    evs = screen.instance_variable_get(:@current_evs)
    evs[1] = 11
    evs[4] = 1
    mon.attack = 149
    mon.spatk = 71
    screen.drawScreen
    screen
  end

  # Runs the block with the player holding money, what they held put back after.
  def with_money(money)
    was = $Trainer.money
    $Trainer.money = money
    yield
  ensure
    $Trainer.money = was
  end

  # Runs the block with a Bitmap whose draw_text answers :drawn where the engine stubs have none, removed after.
  def with_bitmap
    made = !Object.const_defined?(:Bitmap)
    Object.const_set(:Bitmap, Class.new { def draw_text(*_args); :drawn; end }) if made
    yield
  ensure
    Object.send(:remove_const, :Bitmap) if made
  end
end
