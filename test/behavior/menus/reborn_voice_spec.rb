# Reborn's own reader through the engine's relay (rv_common's OwnVoiceRV, installed by games/reborn/own_voice.rb): muted once
# the mod's voice is up, and what it says on the Reborn screens the mod has no reader for said by the mod. The game's
# tts and one of those screens stand in below. The relay is switched off after the suite, since Rejuvenation's reader
# shares this process.
Harness.load_common("rv_common")
def tts(text, _interrupt = false); text; end

class Scene_PulseDex_Info
  def main
    tts("PULSE Dex")
    tts("PULSE 01: Magnezone.")
    :closed
  end
end

# The online trade: the Pokemon under the selector, then the offer, all through tts.
class Scene_Trade
  def main
    tts("Pikachu")
    tts("Pokémon Offered:")
    tts("Level 12 Eevee")
    :traded
  end
end

Suite.define("reborn: its own reader is muted, and its Reborn-only screens are said by the mod") do
  had_tts = $tts
  v = PokeAccess::OwnVoiceRV
  dex = (class << PokeAccess::DexEntry; self; end)
  dex.send(:alias_method, :reborn_spec_gen6_area, :gen6_area)
  sp = (class << PokeAccess; self; end)
  sp.send(:alias_method, :reborn_spec_init, :init_speech!)
  begin
    $tts = lambda { |_m, _i| nil }
    sp.send(:define_method, :init_speech!) { false }
    v.mute
    truthy "without the mod's voice the game's stays, or there would be none", $tts
    sp.send(:define_method, :init_speech!) { true }
    n_over = PokeAccess::Hooks.overrides.length
    load File.expand_path("../../../games/reborn/own_voice.rb", File.dirname(__FILE__))
    eq "with it, the game's is muted", $tts, nil
    falsy "the old Reborn-only relay is gone, so two never run at once", defined?(PokeAccess::RebornVoice)

    SpeakCapture.clear
    tts("Save File: 1")
    silent "a line the game speaks on a screen the mod reads is left to the mod's reader"

    SpeakCapture.clear
    eq "a relayed screen runs as it would", Scene_PulseDex_Info.new.main, :closed
    eq "its lines are said by the mod, as the game wrote them", SpeakCapture.lines,
       ["PULSE Dex", "PULSE 01: Magnezone."]
    eq "the lines of one frame queue behind each other", SpeakCapture.log.map { |l| l[1] }, [false, false]

    SpeakCapture.clear
    Graphics.define_singleton_method(:frame_count) { $reborn_spec_frame.to_i }
    begin
      v.relayed do
        $reborn_spec_frame = 1
        tts("PULSE 01: Magnezone.")
        $reborn_spec_frame = 2
        tts("PULSE 02: Avalugg.")
      end
    ensure
      Graphics.singleton_class.send(:remove_method, :frame_count)
    end
    eq "a later frame's first line cuts in, as a cursor move does", SpeakCapture.log.map { |l| l[1] }, [false, true]

    SpeakCapture.clear
    v.relayed do
      PokeAccess.message_enter
      begin
        tts("A message shown over the dex")
      ensure
        PokeAccess.message_leave
      end
    end
    silent "a message on top of the screen is the dialogue reader's"

    SpeakCapture.clear
    eq "the online trade runs as it would", Scene_Trade.new.main, :traded
    eq "and what it says under the selector and of the offer is said", SpeakCapture.lines,
       ["Pikachu", "Pokémon Offered:", "Level 12 Eevee"]

    SpeakCapture.clear
    tts("X 12, Y 7, map 29, Opal Ward")
    spoke "the Blindstep coordinates are said anywhere", /X 12, Y 7, map 29/

    SpeakCapture.clear
    tts("2 yellow crystals lit up, and 1 white crystals lit up. The slots are filled left to right with ruby, blank, " \
        "blank, blank, blank.")
    spoke "so is the Victory Road crystal count its event only says", /\A2 yellow crystals lit up, and 1 white/

    SpeakCapture.clear
    v.relayed { v.said_already(["The entry in full.", { :tts => false }]) }
    PokeAccess.say_dialogue("The entry in full.")
    silent "an entry the game read aloud before showing it (tts: false) is not read again"

    truthy "the nest page is left to the game's own list of places",
           PokeAccess::Hooks.overrides[n_over..-1].any? { |o| o.include?("DexEntry.gen6_area") }
  ensure
    v.instance_variable_set(:@active, false)
    v.instance_variable_set(:@always, [])
    $tts = had_tts
    sp.send(:alias_method, :init_speech!, :reborn_spec_init)
    sp.send(:remove_method, :reborn_spec_init)
    dex.send(:alias_method, :gen6_area, :reborn_spec_gen6_area)
    dex.send(:remove_method, :reborn_spec_gen6_area)
  end
end
