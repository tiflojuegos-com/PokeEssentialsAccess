# Soulstones 2's Type Match-up chart: its own Kernel.tts lines, dead in the game (TTS_ENABLED false), are relayed
# while the chart is up and nowhere else.
def tts(text, _interrupt = false); text; end

class SpeciesTypeMatch_Scene
  attr_accessor :species, :index, :spoken_full
  def initialize; @species = [1, 4]; @index = 0; @spoken_full = 0; end
  def pbTypeMatchUp
    @init = true
    tts("Type Matchup for Bulbasaur.", true)
    tts("USE Button: Jump to Different Species.")
    drawSpeciesTypes(1)
    :done
  end
  def pbUpdate; :updated; end
  def drawSpeciesTypes(_species, speak = false)
    tts("Type Matchups for Bulbasaur .") unless speak
    @spoken_full += 1 if speak
    tts("Weak to Fire Flying Ice Psychic.") if speak
    @init = false
  end
  def pbChooseSpeciesFromList(default = nil, _current = nil); tts("Bulbasaur"); default; end
  def pbChooseMonoTypeSpecies(default = nil, _current = nil); tts("Select a Type to filter"); tts("Normal"); default; end
end
require File.expand_path("../../../games/soulstones2/type_chart", File.dirname(__FILE__))

Suite.define("soulstones 2 type chart: the mod delivers the words the game already wrote") do
  scene = SpeciesTypeMatch_Scene.new

  SpeakCapture.clear
  tts("algo fuera de la pantalla")
  silent "outside the chart the relay says nothing, or it would double every screen the mod already reads"

  SpeakCapture.clear
  scene.pbTypeMatchUp
  eq "inside it, the screen's own lines are spoken as it wrote them", SpeakCapture.lines,
     ["Type Matchup for Bulbasaur.", "USE Button: Jump to Different Species."]

  SpeakCapture.clear
  tts("otra vez fuera")
  silent "and once the screen is over the relay is quiet again"
end

# The relay leaves out the species list, the type question and any message on top (other readers say them), and the
# first draw, which repeats the opening line.
Suite.define("soulstones 2 type chart: its lists, its question and its first draw are said once") do
  scene = SpeciesTypeMatch_Scene.new
  PokeAccess::SS2TypeChart.enter(scene)
  begin
    SpeakCapture.clear
    eq "the species list hands back what it chose", scene.pbChooseSpeciesFromList(4, 4), 4
    scene.pbChooseMonoTypeSpecies(4, 4)
    silent "the list and the type question are left to the readers that already say them"
    SpeakCapture.clear
    scene.drawSpeciesTypes(4)
    spoke "a species drawn after the opening is announced", /Type Matchups for/
    SpeakCapture.clear
    PokeAccess.message_enter
    begin
      tts("Has elegido a Bulbasaur.")
    ensure
      PokeAccess.message_leave
    end
    silent "a message on top of the chart is the dialogue reader's"
  ensure
    PokeAccess::SS2TypeChart.leave
  end
end

# This game's Effectiveness: exact values per icon (0 immune, 2 a quarter, 4 half, 8 neutral, 16 double,
# 32 quadruple) and a tiny chart against a Rock/Ground defender, the combination that shows every icon.
module SS2ChartFakes
  CHART = { :WATER => 32, :GRASS => 32, :FIGHTING => 16, :NORMAL => 4, :FIRE => 2, :ELECTRIC => 0 }

  Effectiveness = Module.new do
    def self.calculate(attack, _d1, _d2); SS2ChartFakes::CHART.fetch(attack, 8); end
    def self.immune?(v); v == 0; end
    def self.barely_effective?(v); v == 2; end
    def self.not_so_effective?(v); v == 4; end
    def self.pretty_effective?(v); v == 16; end
    def self.hyper_effective?(v); v == 32; end
  end

  Species = Struct.new(:real_name, :form, :real_form_name, :types)
  TypeRow = Struct.new(:id)
end

# Control reads the full match-up (the chart's own branch needs TTS_ENABLED), composed from the icons with the
# chart's Effectiveness calls, a quarter included.
Suite.define("soulstones 2 type chart: Control reads every icon group the chart shows") do
  scene = SpeciesTypeMatch_Scene.new
  scene.species = [:GOLEM]
  types = [:NORMAL, :FIRE, :WATER, :GRASS, :ELECTRIC, :FIGHTING, :ROCK, :QMARKS]
  species_get = GameData::Species.method(:get)
  trig = Input.method(:trigger?)
  begin
    Object.const_set(:Effectiveness, SS2ChartFakes::Effectiveness)
    GameData::Species.define_singleton_method(:get) do |_id|
      SS2ChartFakes::Species.new("Golem", 0, "", [:ROCK, :GROUND])
    end
    GameData::Type.define_singleton_method(:each) { |&b| types.each { |t| b.call(SS2ChartFakes::TypeRow.new(t)) } }
    PokeAccess::SS2TypeChart.enter(scene)
    Input.define_singleton_method(:trigger?) { |k| k == Input::CTRL }

    SpeakCapture.clear
    scene.pbUpdate
    t = PokeAccess::I18n
    eq "species, its types, then each group strongest first, quarter and immunity included",
       SpeakCapture.lines,
       ["Golem. " + t.t(:mv_type, :t => "TypeROCK TypeGROUND") + ". " +
        [[:mv_eff_hyper, "TypeWATER, TypeGRASS"], [:mv_eff_super, "TypeFIGHTING"],
         [:mv_eff_weak, "TypeNORMAL"], [:mv_eff_barely, "TypeFIRE"], [:mv_eff_none, "TypeELECTRIC"]].map do |k, list|
          t.t(:ss2_matchup_group, :eff => t.t(k), :types => list)
        end.join(". ")]
    eq "the screen's own reader, with its wrong groups, is never asked", scene.spoken_full, 0

    Input.define_singleton_method(:trigger?, trig)
    SpeakCapture.clear
    scene.pbUpdate
    silent "a frame with no key press says nothing"
  ensure
    Input.define_singleton_method(:trigger?, trig)
    GameData::Species.define_singleton_method(:get, species_get)
    GameData::Type.singleton_class.send(:remove_method, :each) rescue nil
    Object.send(:remove_const, :Effectiveness) if Object.const_defined?(:Effectiveness)
    PokeAccess::SS2TypeChart.leave
  end
end

Suite.define("soulstones 2 type chart: the keys its own reader names are left out with the hints") do
  scene = SpeciesTypeMatch_Scene.new
  PokeAccess::Config.verbosity = :brief
  begin
    SpeakCapture.clear
    scene.pbTypeMatchUp
    eq "brief: the species, without the line of keys", SpeakCapture.lines, ["Type Matchup for Bulbasaur."]
  ensure
    PokeAccess::Config.verbosity = :full
  end
end
