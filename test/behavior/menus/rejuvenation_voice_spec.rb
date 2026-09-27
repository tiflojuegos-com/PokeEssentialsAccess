# Rejuvenation's own reader through the engine's relay (rv_common's OwnVoiceRV, installed by games/rejuvenation/own_voice.rb):
# muted once the mod's voice is up, and what it hands tts on the Rejuvenation screens the mod has no reader for said
# by the mod. The game's tts and two of those screens stand in below. The relay is switched off after the suite, since
# Reborn's own reader shares this process.
Harness.load_common("rv_common")
def tts(text, _interrupt = false); text; end

class Scene_RiftDex_Info
  def main
    tts("Rift Dex Screen: Use Up or Down keys to switch entries.")
    tts("Rift 1 of 2: Gyarados.")
    :closed
  end
end

class TextLogScene
  attr_reader :held
  def initialize(held)
    @held = held
    tts("Rival: Hello there.")
  end
end

module RejuvVoiceSpec
  # The private-use placeholders the game's messages carry and its tts strips.
  module Placeholders
    SHAKE = [0xE003].pack("U")
    def self.removeFrom(text); text.gsub(SHAKE, ""); end
  end
end

Suite.define("rejuvenation: its own reader is muted, and its Rejuvenation-only screens are said by the mod") do
  had_tts = $tts
  v = PokeAccess::OwnVoiceRV
  dex = (class << PokeAccess::DexEntry; self; end)
  dex.send(:alias_method, :rejuv_spec_gen6_area, :gen6_area)
  sp = (class << PokeAccess; self; end)
  sp.send(:alias_method, :rejuv_spec_init, :init_speech!)
  begin
    sp.send(:define_method, :init_speech!) { true }
    $tts = Object.new
    n_over = PokeAccess::Hooks.overrides.length
    load File.expand_path("../../../games/rejuvenation/own_voice.rb", File.dirname(__FILE__))
    eq "with the mod's voice up, the game's is muted", $tts, nil

    SpeakCapture.clear
    tts("Save File: 1")
    silent "a line the game speaks on a screen the mod reads is left to the mod's reader"

    SpeakCapture.clear
    eq "a relayed screen runs as it would", Scene_RiftDex_Info.new.main, :closed
    eq "its lines are said by the mod, as the game wrote them", SpeakCapture.lines,
       ["Rift Dex Screen: Use Up or Down keys to switch entries.", "Rift 1 of 2: Gyarados."]
    eq "the lines of one frame queue behind each other", SpeakCapture.log.map { |l| l[1] }, [false, false]

    SpeakCapture.clear
    truthy "the text log opens as it would", TextLogScene.new(true).held
    eq "and the line under its cursor is said by the mod", SpeakCapture.lines, ["Rival: Hello there."]

    SpeakCapture.clear
    v.relayed { tts("Sorted by name", :lowercase => false) }
    eq "the lowercase keyword is not taken for the interrupt flag", SpeakCapture.log.map { |l| l[1] }, [false]

    SpeakCapture.clear
    Object.const_set(:TextPlaceholders, RejuvVoiceSpec::Placeholders)
    begin
      v.relayed { tts("Shaking#{RejuvVoiceSpec::Placeholders::SHAKE} ground") }
    ensure
      Object.send(:remove_const, :TextPlaceholders)
    end
    eq "the game's placeholders are stripped, as its own tts does", SpeakCapture.lines, ["Shaking ground"]

    SpeakCapture.clear
    v.relayed do
      PokeAccess.message_enter
      begin
        tts("A message shown over the log")
      ensure
        PokeAccess.message_leave
      end
    end
    silent "a message on top of the screen is the dialogue reader's"

    SpeakCapture.clear
    v.relayed { v.said_already(["The note in full.", { :tts => false }]) }
    PokeAccess.say_dialogue("The note in full.")
    silent "a note the game read aloud before showing it (tts: false) is not read again"

    falsy "its nest is its region map, which the mod reads, so no gen-6 nest page is left to the game",
          PokeAccess::Hooks.overrides[n_over..-1].any? { |o| o.include?("DexEntry.gen6_area") }
  ensure
    v.instance_variable_set(:@active, false)
    $tts = had_tts
    sp.send(:alias_method, :init_speech!, :rejuv_spec_init)
    sp.send(:remove_method, :rejuv_spec_init)
    dex.send(:alias_method, :gen6_area, :rejuv_spec_gen6_area)
    dex.send(:remove_method, :rejuv_spec_gen6_area)
  end
end

Suite.define("rejuvenation: the relay stays out of the way until a profile installs it") do
  v = PokeAccess::OwnVoiceRV
  eq "a screen runs untouched", v.relayed { :ran }, :ran
  falsy "and nothing is taken for a relayed screen", v.relaying?
  SpeakCapture.clear
  v.relay("Rift 1 of 2: Gyarados.")
  silent "a line handed to the game's reader is not said"
end
