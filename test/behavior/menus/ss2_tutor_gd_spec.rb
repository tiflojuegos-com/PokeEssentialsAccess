# Tutor.net's party half: a grid of panel SPRITES with its own pbChangeSelection, and above each panel an
# icon TINT that says whether that member can learn the move -- 1 can, 2 cannot, 3 already knows it. The
# tint is the entire point of the screen and it is a colour: the player walked six panels that all sounded
# the same and paid for a move the pokemon could not learn.
class PokemonTutorNet_Scene
  attr_reader :sprites
  attr_accessor :activecmd
  def initialize(party, comps)
    @party = party
    @activecmd = 0
    @sprites = {}
    party.each_with_index do |_pk, i|
      panel = Object.new
      panel.instance_variable_set(:@c, comps[i])
      def panel.pkmn_comp; @c; end
      def panel.comp=(v); @c = v; end
      @sprites["pokemon#{i}"] = panel
    end
  end
  def pbChangeSelection(_key, currentsel); @activecmd = currentsel; end
  def update_indicators; :drawn; end
  def set_comp(i, v); @sprites["pokemon#{i}"].comp = v; end
end
require File.expand_path("../../../games/soulstones2/tutor_net", File.dirname(__FILE__))
require File.expand_path("../../../games/soulstones2/own_tts", File.dirname(__FILE__))

Suite.define("soulstones 2 tutor: each party panel says whether it can learn the move") do
  a = Poke.build(:name => "Chispa")
  b = Poke.build(:name => "Brasa")
  scene = PokemonTutorNet_Scene.new([a, b], [1, 2])

  SpeakCapture.clear
  scene.pbChangeSelection(nil, 0)
  line = SpeakCapture.lines.join(" ")
  match "the member is named", line, /Chispa/
  match "and the tint is put into words", line, /#{PokeAccess::I18n.t(:tut_can)}/

  SpeakCapture.clear
  scene.pbChangeSelection(nil, 1)
  match "the next panel says its own verdict", SpeakCapture.lines.join(" "),
        /#{PokeAccess::I18n.t(:tut_cannot)}/

  SpeakCapture.clear
  scene.pbChangeSelection(nil, 1)
  silent "and standing still says nothing"

  # Moving the LIST repaints every tint without moving the party cursor, so the focused one is read again.
  scene.set_comp(1, 3)
  SpeakCapture.clear
  scene.update_indicators
  match "a repaint that changed the verdict says the new one", SpeakCapture.lines.join(" "),
        /#{PokeAccess::I18n.t(:tut_knows)}/
end

# The game ships a screen reader of its own (Reborn TextToSpeech, a hundred and ten calls). It is off in the
# shipped scripts, so the mod is the only voice -- but a player who turns it on hears everything twice, and
# that is exactly what this game was reported for. The mod cannot pick which to silence, so it says so once.
Suite.define("soulstones 2: two voices at once are reported, once, and only when there really are two") do
  had = Object.const_defined?(:TTS_ENABLED)
  begin
    PokeAccess::SS2OwnTTS.forget
    Object.const_set(:TTS_ENABLED, false) unless had
    SpeakCapture.clear
    PokeAccess::SS2OwnTTS.warn_once
    silent "with the game's reader off there is nothing to warn about"

    PokeAccess::SS2OwnTTS.forget
    Object.send(:remove_const, :TTS_ENABLED)
    Object.const_set(:TTS_ENABLED, true)
    SpeakCapture.clear
    PokeAccess::SS2OwnTTS.warn_once
    eq "with it on the player is told, and told what to edit",
       SpeakCapture.lines, [PokeAccess::I18n.t(:ss2_two_voices)]

    SpeakCapture.clear
    PokeAccess::SS2OwnTTS.warn_once
    silent "and only once, not on every map change"
  ensure
    Object.send(:remove_const, :TTS_ENABLED) if Object.const_defined?(:TTS_ENABLED)
    PokeAccess::SS2OwnTTS.forget
  end
end
