# Realidea's two story-critical minigames. These are not optional content: Mankey is launched from the battle
# code (0084_PokeBattle_Battle) and from the pirates event, and Pesca is the game's general fishing
# (0098_PField_Field), so being unable to play them blocks progress outright.
#
# Both expose a method that runs once per frame from inside their own loop -- Pesca#input and Mankey#inputs,
# which is where each reads its keys -- so hooking those directly is enough; no held-instance poller needed.
#
# Pesca is a TIMING game dressed as a Fire Emblem duel: a circle sprite cycles @frame through 1..18 and C
# resolves the hit. The payoff table, rival damage against own damage: frame 11 is 40 for nothing, 10 and 12
# are 30 for 10, 9 and 13 are 20 for 20, and anything else is 10 for 30. So 11 is the only frame that costs
# the player nothing, which is where the tick's pitch peaks. Speech would arrive after the window closed,
# which is why this one is a cue and not a sentence.
#
# Mankey is turn-based, so it reads normally: @seleccion walks $Trainer.contestaciones (the replies, already
# plain text) and @vidasprota / @vidasenemigo are the hearts, which are drawn as sprites -- without this you
# cannot tell how close the duel is to ending.
module PokeAccess
  module RealideaStory
    PERFECT_FRAME = 11

    # Ticks once per frame step, pitch peaking on the perfect frame so the timing is audible.
    def self.pesca(scene)
      f = PokeAccess.ivar(scene, :@frame)
      if !f.nil? && PokeAccess.ivar(scene, :@pa_frame) != f
        scene.instance_variable_set(:@pa_frame, f)
        PokeAccess::Spatial.gauge(1.0 - ((f.to_i - PERFECT_FRAME).abs / 6.0))
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
    #
    # The TURN is in the dedup key, not just the index and the length. Which of the two lists is showing --
    # the comebacks or the insults -- is @turno, and both start at two entries and grow together, so with the
    # same cursor on a same-sized list the line changed from one to the other and the reader said nothing.
    def self.mankey(scene)
      lives = PokeAccess.ivar(scene, :@vidasprota)
      elives = PokeAccess.ivar(scene, :@vidasenemigo)
      if !lives.nil? && PokeAccess.ivar(scene, :@pa_lives) != [lives, elives]
        scene.instance_variable_set(:@pa_lives, [lives, elives])
        PokeAccess.speak(PokeAccess::I18n.t(:rea_hearts, :n => lives.to_i, :e => elives.to_i), false)
      end
      idx = PokeAccess.ivar(scene, :@seleccion)
      list = mankey_list(scene)
      return unless idx.is_a?(Integer) && list.is_a?(Array) && idx >= 0 && idx < list.length
      PokeAccess::Cursor.announce(scene, :rea_mankey, [idx, list.length, PokeAccess.ivar(scene, :@turno)], true) do
        PokeAccess::I18n.t(:list_entry, :name => PokeAccess.clean(list[idx].to_s),
                           :n => idx + 1, :tot => list.length)
      end
    rescue StandardError
      nil
    end

    # The line list the duel is currently showing. It ALTERNATES: on turn 1 the player picks a comeback from
    # $Trainer.contestaciones, otherwise an insult from $Trainer.insultos -- and it starts on turn 0, so
    # fixing on the comeback list read the wrong line from the very first turn, and fell silent whenever the
    # insult list was the longer of the two and the cursor went past the comeback list's end.
    def self.mankey_list(scene)
      src = (PokeAccess.ivar(scene, :@turno) == 1) ? ($Trainer.contestaciones rescue nil) :
                                                     ($Trainer.insultos rescue nil)
      src.is_a?(Array) ? src : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("realidea") do
  # hook_container: at zero enemy HP input opens the whole ball-choosing bag screen from inside, so an
  # atomic guard would discard every reader hook nested under it.
  after("Pesca", :input, :hook_container => true) { |s, _r, _a| PokeAccess::RealideaStory.pesca(s) }
  after("Mankey", :inputs) { |s, _r, _a| PokeAccess::RealideaStory.mankey(s) }
end
