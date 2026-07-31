# Realidea's two story-critical minigames. These are not optional content: Mankey is launched from the battle
# code (0084_PokeBattle_Battle:3201) and from the pirates event, and Pesca is the game's general fishing
# (0098_PField_Field:1667), so being unable to play them blocks progress outright.
#
# Both expose a method that runs once per frame from inside their own loop -- Pesca#input and Mankey#inputs,
# which is where each reads its keys -- so hooking those directly is enough; no held-instance poller needed.
#
# Pesca is a TIMING game dressed as a Fire Emblem duel: a circle sprite cycles @frame through 1..18 and C
# resolves the hit. Its `resultado` shows the payoff curve -- frame 11 takes 40 HP off the rival, 10 and 12
# take 30, 9 and 13 take 20 and also cost the player HP -- so 11 is the sweet spot and the tick's pitch peaks
# there. Speech would arrive after the window closed, which is why this one is a cue and not a sentence.
#
# Mankey is turn-based, so it reads normally: @seleccion walks $Trainer.contestaciones (the replies, already
# plain text) and @vidasprota / @vidasenemigo are the hearts, which are drawn as sprites -- without this you
# cannot tell how close the duel is to ending.
module PokeAccess
  module RealideaStory
    TICK = "pa_mg_tick"
    PERFECT_FRAME = 11

    # Ticks once per frame step, pitch peaking on the perfect frame so the timing is audible.
    def self.pesca(scene)
      f = PokeAccess.ivar(scene, :@frame)
      if !f.nil? && PokeAccess.ivar(scene, :@pa_frame) != f
        scene.instance_variable_set(:@pa_frame, f)
        closeness = 1.0 - ((f.to_i - PERFECT_FRAME).abs / 6.0)
        closeness = 0.0 if closeness < 0
        PokeAccess::Spatial.cue(TICK, 60, 80 + (closeness * 100).to_i)
      end
      hp = PokeAccess.ivar(scene, :@protahp)
      ehp = PokeAccess.ivar(scene, :@enemhp)
      sig = [hp, ehp]
      return if hp.nil? || PokeAccess.ivar(scene, :@pa_hp) == sig
      scene.instance_variable_set(:@pa_hp, sig)
      PokeAccess.speak(PokeAccess::I18n.t(:rea_hp, :hp => hp.to_i, :ehp => ehp.to_i), false)
    rescue StandardError
      nil
    end

    # Speaks the focused reply, and the hearts left on each side whenever one is lost.
    def self.mankey(scene)
      lives = PokeAccess.ivar(scene, :@vidasprota)
      elives = PokeAccess.ivar(scene, :@vidasenemigo)
      if !lives.nil? && PokeAccess.ivar(scene, :@pa_lives) != [lives, elives]
        scene.instance_variable_set(:@pa_lives, [lives, elives])
        PokeAccess.speak(PokeAccess::I18n.t(:rea_hearts, :n => lives.to_i, :e => elives.to_i), false)
      end
      idx = PokeAccess.ivar(scene, :@seleccion)
      list = ($Trainer.contestaciones rescue nil)
      return unless idx.is_a?(Integer) && list.is_a?(Array) && idx >= 0 && idx < list.length
      PokeAccess::Cursor.announce(scene, :rea_mankey, idx, true) do
        PokeAccess::I18n.t(:if2_pokenav, :name => PokeAccess.clean(list[idx].to_s),
                           :n => idx + 1, :tot => list.length)
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("realidea") do
  after("Pesca", :input) { |s, _r, _a| PokeAccess::RealideaStory.pesca(s) }
  after("Mankey", :inputs) { |s, _r, _a| PokeAccess::RealideaStory.mankey(s) }
end
