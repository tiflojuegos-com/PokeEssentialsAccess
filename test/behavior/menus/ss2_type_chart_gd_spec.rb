# The Type Match-up chart: a grid of coloured type icons and nothing else. It was WRITTEN for a screen
# reader -- the scene announces its controls, the focused species and the whole match-up through
# Kernel.tts -- and every one of those calls is dead, because the plugin they belong to ships with
# TTS_ENABLED = false. The words exist and never leave the game.
def tts(text, _interrupt = false); text; end

class SpeciesTypeMatch_Scene
  attr_accessor :species, :index, :spoken_full
  def initialize; @species = [1, 4]; @index = 0; @spoken_full = 0; end
  def pbTypeMatchUp
    tts("Type Matchup for Bulbasaur.", true)
    tts("USE Button: Jump to Different Species.")
    :done
  end
  def pbUpdate; :updated; end
  def drawSpeciesTypes(_species, speak = false)
    @spoken_full += 1 if speak
    tts("Weak to Fire Flying Ice Psychic.") if speak
  end
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

# The chart reads the FULL match-up on Control, but that branch is written "&& TTS_ENABLED", so with the
# flag off the key does nothing. The mod calls the screen's own method with the argument it wanted.
Suite.define("soulstones 2 type chart: Control reads the whole match-up, which the flag had disabled") do
  scene = SpeciesTypeMatch_Scene.new
  saved = $pa_spec_dir4
  begin
    PokeAccess::SS2TypeChart.enter(scene)
    trig = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |k| k == Input::CTRL }

    SpeakCapture.clear
    scene.pbUpdate
    eq "the screen's own reader ran, once", scene.spoken_full, 1
    match "and what it wrote is what is heard", SpeakCapture.lines.join(" "), /Weak to Fire/

    Input.define_singleton_method(:trigger?, trig)
    SpeakCapture.clear
    scene.pbUpdate
    eq "a frame with no key press asks for nothing", scene.spoken_full, 1
  ensure
    PokeAccess::SS2TypeChart.leave
    $pa_spec_dir4 = saved
  end
end
