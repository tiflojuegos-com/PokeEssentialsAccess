# Awakening's own screens, driven through the profile's hooks on stand-ins shaped as its classes: the class picker, the
# diary, the EV redistributor, the ball picker, tea time, PsyduckHunt, Kyu's autosave, the Critical Quotes and the lists
# that screens close back onto. The stand-ins exist before the profile files load, so their hooks bind once.
module Fates_Utilities
  def self.checkIfHasClass(_who, cls); cls != "Ladrón"; end
end

# Fates_Menu_Personajes, as its initialize leaves it for the loop: the class list, the focus and the detail panel.
class Fates_Menu_Personajes
  TIMESKIPSWITCH = 468
  TIMESKIP = { "Aldeano" => "Elegido" }
  TEXTOS = { "Lana" => { "Elegido" => "La elegida por el universo.", "Aldeano" => "Pueblerina valiente.",
                         "Aprendiz" => "Principiante en la magia." } }
  HABS = { "Lana" => { "Aldeano" => "Ninguna.", "Aprendiz" => ">Miscelánea." } }

  def initialize(sel = 0)
    @name = "Lana"
    @classArray = ["Aldeano", "Aprendiz", "Ladrón"]
    @select = sel
    @sprites = { "Base" => Struct.new(:visible).new(false) }
  end

  def habs2_text(nombre, clase, nivel); "Senda de #{clase} para #{nombre}\nNivel #{nivel}."; end
  def showLoreWindow(_title, _text); :lore_closed; end
end

class Scene_Glosario
  def initialize; @index = 0; @commands = ["Historia", "Personajes"]; end
  def main; :closed; end
  def refresh; :refreshed; end
end

class ListaAngeles
  def initialize(rows); @select = 0; @opciones = rows; end
  def update; :updated; end
  def pbDatosAngel(_num); :sheet_closed; end
end

# EVReorganizeScene with its own cost rule (500 a point added) and its two highest base stats, Attack and Sp. Atk.
class EVReorganizeScene
  STAT_ORDER = [0, 1, 2, 4, 5, 3]

  def initialize(pokemon, evs)
    @pokemon = pokemon
    @original_evs = evs.dup
    @current_evs = evs
    @ivs = [31] * 6
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

# A PsyduckHunt round: pbUpdate is BaseMinigame's loop, one frame poll per frame; here a hit, then the end.
class PsyduckHunt
  def initialize; @score = 0; @hits = 0; @pause = false; @framesLeft = 300; @totalFrames = 300; end

  def pbUpdate
    PokeAccess::Keys.run_frame_pollers
    @score = 500
    @hits = 1
    PokeAccess::Keys.run_frame_pollers
    :round_over
  end
end

def autosaveAnim; :slid; end

%w[outfits glossary compendium extras tea_time psyduck_hunt].each do |f|
  load File.join(Harness::ROOT, "games", "awakening", "#{f}.rb")
end
load File.join(Harness::ROOT, "games", "awakening", "fates_screens.rb") unless defined?(PokeAccess::AwakeningFates)

Suite.define("awakening classes: a locked class as its picture paints it, an unlocked one with its data, panel and lore") do
  t = PokeAccess::I18n
  reader = PokeAccess::AwakeningOutfits
  meta = class << $game_player; self; end
  had = $game_player.respond_to?(:clases)
  meta.send(:define_method, :clases) { { "Lana" => { "Aldeano" => 2, "Aprendiz" => 1 } } }
  s = Fates_Menu_Personajes.new(2)
  begin
    reader.watch(s)
    reader.poll
    eq "a locked class: no name and no data, as the ND picture shows", SpeakCapture.lines, [t.t(:aw_outfit_locked)]
    falsy "the name the screen hides is not said", SpeakCapture.last.to_s.include?("Ladr")
    SpeakCapture.clear
    s.instance_variable_set(:@select, 1)
    reader.poll
    head = "Aprendiz, #{t.t(:awk_class_level, :n => 1)}, #{t.t(:awk_class_ability, :name => 'Miscelánea.')}"
    eq "unlocked: its name, level and ability (no bullet), and in full its description", SpeakCapture.lines,
       ["#{head} Principiante en la magia."]
    eq "the info key keeps it all", PokeAccess::Info.info_text, "#{head} Principiante en la magia."
    PokeAccess::Config.verbosity = :medium
    PokeAccess::Cursor.reset(reader, :aw_outfit)
    SpeakCapture.clear
    reader.poll
    eq "below full, the description waits on the info key", SpeakCapture.lines, [head]
    PokeAccess::Config.verbosity = :full
    SpeakCapture.clear
    s.instance_variable_get(:@sprites)["Base"].visible = true
    reader.poll
    eq "the detail panel (Z): its text", SpeakCapture.lines, ["Senda de Aprendiz para Lana Nivel 1."]
    s.instance_variable_get(:@sprites)["Base"].visible = false
    $game_switches[468] = true
    s.instance_variable_set(:@select, 0)
    SpeakCapture.clear
    reader.poll
    eq "after the time skip: the class shown, its level and ability kept on the one listed", SpeakCapture.lines,
       ["Elegido, #{t.t(:awk_class_level, :n => 2)}, #{t.t(:awk_class_ability, :name => 'Ninguna.')} La elegida por el universo."]
    SpeakCapture.clear
    eq "the lore window runs as the game's own", s.showLoreWindow("Elegido", "Nacida del destino."), :lore_closed
    eq "it says its title and its lore", SpeakCapture.lines, ["#{t.t(:awk_class_lore, :name => 'Elegido')}. Nacida del destino."]
    SpeakCapture.clear
    reader.poll
    truthy "and the class is said again once it closes", SpeakCapture.last.to_s.index("Elegido") == 0
  ensure
    reader.unwatch
    meta.send(:remove_method, :clases) unless had
  end
end

Suite.define("awakening diary: the sibling placeholder named as the page paints it, and a biography's headings") do
  t = PokeAccess::I18n
  story = PokeAccess::AwakeningStoryGlossary
  af = PokeAccess::AwakeningFates
  scene = World.stub_scene(:@secciones => { "Capitulo 1" => ["siblingA me encontro espiando la cascada."] })
  $game_switches[80] = true
  eq "switch 80: Liam", story.body(scene, "Capitulo 1", 0),
     t.t(:awk_glos_bio, :name => "Capitulo 1", :page => 1, :pages => 1, :text => "Liam me encontro espiando la cascada.")
  $game_switches[80] = false
  $game_switches[81] = true
  truthy "switch 81: Lana", story.body(scene, "Capitulo 1", 0).to_s.include?("Lana me encontro")

  overlay = Struct.new(:visible).new(false)
  bio = World.stub_scene(:@overlay => overlay, :@secciones => { "Holly" => { "text" => ["siblingA y Holly.", "Segunda."],
                                                                            "afinidad" => "Neutral",
                                                                            "localidad" => "Verbena" } })
  label = ["Holly", t.t(:awk_glos_aff, :name => "Neutral"), t.t(:awk_glos_loc, :name => "Verbena")].join(". ")
  af.watch(bio, "Holly")
  begin
    af.on_draw("1/2")
    eq "a biography opens with its affinity and place, and its sibling named", SpeakCapture.lines,
       [t.t(:awk_glos_bio, :name => label, :page => 1, :pages => 2, :text => "Lana y Holly.")]
    SpeakCapture.clear
    af.on_draw("2/2")
    eq "its next page, without them", SpeakCapture.lines,
       [t.t(:awk_glos_bio, :name => "Holly", :page => 2, :pages => 2, :text => "Segunda.")]
  ensure
    af.unwatch
  end
end

class AwkEvMon
  attr_accessor :totalhp, :attack, :defense, :speed, :spatk, :spdef, :nature
  def initialize; @totalhp = 200; @attack = 150; @defense = 90; @speed = 80; @spatk = 70; @spdef = 60; @nature = 7; end
  def isShadow?; false; end
end

# Nature 7 lands drawScreen's red on stat index 1 (Attack) and its blue on 2 (Defense), the nature's own numbering.
Suite.define("awakening EVs: each row as painted, an EV step with what is left and its cost, and the Confirm row") do
  t = PokeAccess::I18n
  data = PokeAccess::Data
  mon = AwkEvMon.new
  s = EVReorganizeScene.new(mon, [4, 12, 0, 0, 0, 0])
  old_money = $Trainer.money
  $Trainer.money = 300
  begin
    s.drawScreen
    eq "HP: its value, EV and IV", SpeakCapture.lines,
       [t.t(:awk_ev_row, :name => data.stat_name(0), :value => 200, :ev => 4, :iv => 31)]
    SpeakCapture.clear
    s.instance_variable_set(:@selected_stat, 1)
    s.drawScreen
    eq "Attack: red for the nature, and marked recommended", SpeakCapture.lines,
       [[t.t(:awk_ev_row, :name => data.stat_name(1), :value => 150, :ev => 12, :iv => 31), t.t(:awk_ev_nat_up),
         t.t(:awk_ev_recommended)].join(", ")]
    SpeakCapture.clear
    s.instance_variable_get(:@current_evs)[1] = 11
    mon.attack = 149
    s.drawScreen
    eq "a step down: the EVs, the new value, what is left and the cost", SpeakCapture.lines,
       ["#{t.t(:awk_ev_change, :ev => 11, :name => data.stat_name(1), :value => 149)}. " \
        "#{t.t(:awk_ev_left, :n => 1)}. #{t.t(:awk_ev_cost, :n => 0)}"]
    SpeakCapture.clear
    s.instance_variable_set(:@selected_stat, 3)
    s.drawScreen
    s.instance_variable_get(:@current_evs)[4] = 1
    mon.spatk = 71
    SpeakCapture.clear
    s.drawScreen
    eq "a point added: its cost, and the red of a cost past the money", SpeakCapture.lines,
       ["#{t.t(:awk_ev_change, :ev => 1, :name => data.stat_name(4), :value => 71)}. " \
        "#{t.t(:awk_ev_left, :n => 0)}. #{t.t(:awk_ev_cost, :n => 500)}, #{t.t(:awk_ev_short)}"]
    SpeakCapture.clear
    s.instance_variable_set(:@selected_stat, 6)
    s.drawScreen
    eq "Confirm: the totals, what is left and the cost", SpeakCapture.lines,
       ["#{t.t(:pc_confirm)}. #{t.t(:awk_ev_totals, :n => 16, :max => 16)}. #{t.t(:awk_ev_left, :n => 0)}. " \
        "#{t.t(:awk_ev_cost, :n => 500)}, #{t.t(:awk_ev_short)}"]
    SpeakCapture.clear
    s.instance_variable_set(:@selected_stat, 2)
    s.drawScreen
    eq "Defense: blue for the nature", SpeakCapture.lines,
       ["#{t.t(:awk_ev_row, :name => data.stat_name(2), :value => 90, :ev => 0, :iv => 31)}, #{t.t(:awk_ev_nat_down)}"]
  ensure
    $Trainer.money = old_money
  end
end

Suite.define("awakening ball picker: the ball and how many are left, and in full the description painted under it") do
  t = PokeAccess::I18n
  af = PokeAccess::AwakeningFates
  data = PokeAccess::Data
  desc = data.method(:item_description)
  data.define_singleton_method(:item_description) { |_id| "Una ball de alto rendimiento." }
  begin
    scene = World.stub_scene(:@index => 0, :@ball_list => [1], :@ball_counts => [5])
    head = t.t(:awk_ball, :name => data.item_name(1), :n => 5)
    rows = vb_levels do
      PokeAccess::Cursor.reset(scene, :awk_ball)
      SpeakCapture.clear
      af.ball(scene)
      SpeakCapture.last
    end
    eq "brief and medium: the ball and its count", rows[0, 2], [head, head]
    eq "full: and its description", rows[2], "#{head}. Una ball de alto rendimiento."
  ensure
    data.define_singleton_method(:item_description, desc)
  end
end

Suite.define("awakening tea time: Observe says whom, and with hints on how to move the picture and leave") do
  t = PokeAccess::I18n
  s = Scene_HoraDelTe.new("Holly")
  eq "Observe runs as the game's own", s.observar_personaje, :observed
  eq "whom, and its keys", SpeakCapture.lines, ["#{t.t(:awk_observe, :name => 'Holly')}. #{t.t(:awk_observe_keys)}"]
  PokeAccess::Config.verbosity = :brief
  SpeakCapture.clear
  s.observar_personaje
  eq "hints off: whom alone", SpeakCapture.lines, [t.t(:awk_observe, :name => "Holly")]
end

Suite.define("awakening PsyduckHunt: the score and hits as they change, the pause, the time bar and the final score") do
  t = PokeAccess::I18n
  d = PokeAccess::AwakeningPsyduck
  eq "a round runs as the game's own", PsyduckHunt.new.pbUpdate, :round_over
  eq "a hit with its score, then the final score", SpeakCapture.lines,
     [t.t(:awk_duck_score, :n => 500, :hits => 1), t.t(:awk_duck_final, :n => 500)]
  SpeakCapture.clear
  s = World.stub_scene(:@score => 0, :@hits => 3, :@pause => false, :@framesLeft => 300, :@totalFrames => 300)
  d.watch(s)
  begin
    d.poll
    s.instance_variable_set(:@pause, true)
    d.poll
    eq "the pause, with how to quit", SpeakCapture.lines, ["#{t.t(:awk_duck_pause)}. #{t.t(:awk_duck_quit_key)}"]
    SpeakCapture.clear
    s.instance_variable_set(:@pause, false)
    s.instance_variable_set(:@hits, 0)
    d.poll
    eq "resumed, and a miss that drops the hits", SpeakCapture.lines,
       ["#{t.t(:awk_duck_resume)}. #{t.t(:awk_duck_hits, :n => 0)}"]
    SpeakCapture.clear
    s.instance_variable_set(:@framesLeft, 70)
    d.poll
    eq "the time bar crossing a mark", SpeakCapture.lines, [t.t(:awk_duck_time, :n => 25)]
    SpeakCapture.clear
    s.instance_variable_set(:@framesLeft, 69)
    d.poll
    silent "and nothing more until the next mark"
  ensure
    d.unwatch
  end
end

Suite.define("kyu autosave: the green star that slides in on a map change is said") do
  unless $pa_kyu_autosave_loaded
    load File.join(Harness::ROOT, "plugins", "kyu_autosave.rb")
    $pa_kyu_autosave_loaded = true
  end
  SpeakCapture.clear
  eq "the animation runs as the game's own", autosaveAnim, :slid
  eq "said, queued", SpeakCapture.log, [[PokeAccess::I18n.t(:kyu_autosaved), false]]
end

# The tab menu and the compendium lists repaint themselves as a screen opened from them closes: the focus again.
Suite.define("awakening lists: the tab menu and a compendium list say their focus again behind a closed screen") do
  reader = PokeAccess::AwakeningGlossary
  menu = Scene_Glosario.new
  reader.watch(menu)
  begin
    reader.poll
    eq "the tab menu's focus", SpeakCapture.lines, ["Historia"]
    SpeakCapture.clear
    reader.poll
    silent "said once"
    eq "the menu redraws as the game's own", menu.refresh, :refreshed
    reader.poll
    eq "and closing a tab back onto it says the focus again", SpeakCapture.lines, ["Historia"]
  ensure
    reader.unwatch
  end
  SpeakCapture.clear
  row = Struct.new(:nombre)
  list = ListaAngeles.new([row.new("Miguel"), row.new("Rafael")])
  list.update
  entry = PokeAccess::Verbosity.list_entry("Miguel", 1, 2)
  eq "a compendium list's focus", SpeakCapture.lines, [entry]
  SpeakCapture.clear
  list.update
  silent "said once"
  eq "a sheet runs as the game's own", list.pbDatosAngel(0), :sheet_closed
  SpeakCapture.clear
  list.update
  eq "and the list says it again once the sheet closes", SpeakCapture.lines, [entry]
end

# Critical_Quotes paints its line with Bitmap#draw_text, which no capture sees; its initialize runs the whole cut-in.
Suite.define("awakening Critical Quotes: the line drawn in the cut-in is said, and draw_text is left as it was") do
  made_bitmap = !Object.const_defined?(:Bitmap)
  made_quote = !Object.const_defined?(:Critical_Quotes)
  Object.const_set(:Bitmap, Class.new { def draw_text(*_a); :drawn; end }) if made_bitmap
  if made_quote
    Object.const_set(:Critical_Quotes, Class.new do
      def initialize(_mug)
        Bitmap.new.draw_text(0, 0, 512, 384, "Podrías hacerlo mejor, hermana.", 1)
        Bitmap.new.draw_text(Object.new, "Segunda linea.")
      end
    end)
  end
  begin
    load File.join(Harness::ROOT, "games", "awakening", "quotes.rb")
    Critical_Quotes.new("Liam")
    eq "each line the cut-in draws, queued", SpeakCapture.log,
       [["Podrías hacerlo mejor, hermana.", false], ["Segunda linea.", false]]
    SpeakCapture.clear
    eq "after it, draw_text is the game's own", Bitmap.new.draw_text(0, 0, 10, 10, "Hola"), :drawn
    silent "and speaks nothing"
  ensure
    Object.send(:remove_const, :Critical_Quotes) if made_quote && Object.const_defined?(:Critical_Quotes)
    Object.send(:remove_const, :Bitmap) if made_bitmap && Object.const_defined?(:Bitmap)
  end
end
