# Realidea's two story minigames, read from their per-frame methods: Pesca (fishing), a timing game whose @frame
# cycles 1..18 with 11 the only frame that costs nothing, and Mankey, a duel of replies and hearts.
module PokeAccess
  module RealideaStory
    PERFECT_FRAME = 11
    # The picture each press shows, by the frame it lands on (resultado): PERFECT on 11, GREAT beside it, GOOD
    # one further, BAD elsewhere.
    RATINGS = { 11 => :rea_pesca_perfect, 10 => :rea_pesca_great, 12 => :rea_pesca_great, 9 => :rea_pesca_good,
                13 => :rea_pesca_good }

    # The Pokemon on the hook, as its box paints it ("<name> Lv.<n>"), once as the minigame opens.
    def self.pesca_foe(scene)
      pk = PokeAccess.ivar(scene, :@pokemon)
      return unless pk && PokeAccess::Cursor.changed?(scene, :rea_pesca_foe, true)
      name = (pk.name rescue nil).to_s
      PokeAccess.speak(PokeAccess::I18n.t(:rea_pesca_foe, :name => name, :level => PokeAccess.ivar_i(scene, :@nivel)), true)
    end

    # The rating a press earns, as the picture resultado shows for the frame it lands on.
    def self.pesca_rating(scene)
      PokeAccess.speak(PokeAccess::I18n.t(RATINGS[PokeAccess.ivar_i(scene, :@frame)] || :rea_pesca_bad), true)
    rescue StandardError
      nil
    end

    # Ticks once per frame step, pitch peaking on the perfect frame so the timing is audible.
    def self.pesca(scene)
      pesca_foe(scene)
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

    # Speaks the focused reply, and the hearts left on each side whenever one is lost; the dedup key holds @turno,
    # as the two lists can match in cursor and length.
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
        PokeAccess::Verbosity.list_entry(PokeAccess.clean(list[idx].to_s), idx + 1, list.length)
      end
    rescue StandardError
      nil
    end

    # The list the duel shows: $Trainer.contestaciones (comebacks) on turn 1, else $Trainer.insultos (insults).
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
  before("Pesca", :resultado) { |s, _a| PokeAccess::RealideaStory.pesca_rating(s) }
  after("Mankey", :inputs) { |s, _r, _a| PokeAccess::RealideaStory.mankey(s) }
end
