# Two more Fates screens reached from the CMoon hub.
#
# FatesCartas (0260) is the character relationship cards: a vertical list of panels with @posi as the focus,
# each panel a ListaPersonaje carrying the character's @nombre and their rank. The cards themselves are art,
# so the name and rank are the whole content for a blind player.
#
# Scene_HoraDelTe (0261) is the tea-time social minigame: @tes lists the teas to offer, @puntos is the
# affinity earned and @personaje_nombre who you invited. The dialogue goes through pbMessage (already read);
# what was missing is the choice itself and the score.
module PokeAccess
  module AwakeningFatesExtra
    @cards_class = nil

    # FatesCartas is entered through self.main and keeps its whole state on the class, so there is no
    # instance for SceneWatcher to hold and the reader has to poll. Polling means every frame of the
    # entire game, forever, so the screen announces itself rather than being searched for: main is
    # wrapped, and the poller's first line is then a nil check instead of a const lookup by name plus
    # three ivar reads. Holding the class object is the other half -- it is resolved once, on open.
    def self.watch_cards(klass); @cards_class = klass; end
    def self.unwatch_cards; @cards_class = nil; end

    # Voices the focused relationship card: the character and their rank.
    #
    # The panel is keyed by @posi directly, exactly as the screen keys it (`@paneles["#{@posi}"]`). The
    # panels are built with a sequential counter while @master_index holds each card's own slot in
    # $Trainer.lista_cartas, a different number because the build loop skips empty slots, so going through
    # it drifts apart from the row as soon as one earlier card is locked.
    #
    # The dedup key carries the panel table's IDENTITY as well as the index, because this screen has no
    # instance to hang the dedup on and lands in Cursor's module-wide table, which outlives it, while
    # reopening always starts at @posi = 0. The game rebuilds @paneles on every open, which is what makes it
    # a new key. The name and rank come through the panel's CHARACTER and not off the panel, which is a
    # CartasPaneles sprite holder carrying neither, with the character hanging off its pj accessor.
    def self.cards(_scene)
      return unless @cards_class
      idx = PokeAccess::AwakeningFatesExtra.mod_ivar(:@posi)
      panels = PokeAccess::AwakeningFatesExtra.mod_ivar(:@paneles)
      return unless idx.is_a?(Integer) && panels.is_a?(Hash)
      panel = panels[idx.to_s]
      return unless panel
      rng = PokeAccess::AwakeningFatesExtra.mod_ivar(:@rng_pos)
      PokeAccess::Cursor.announce(nil, :awk_cards, [idx, rng, panels.__id__], true) do
        pj = (panel.pj rescue nil)
        name = PokeAccess.clean((pj.nombre rescue "").to_s).to_s.strip
        rank = (pj.rango_letras rescue nil)
        t = rank ? "#{name}, #{rank}" : name
        max = (panel.rango rescue nil)
        if rng.is_a?(Integer) && max
          t += ", " + PokeAccess::I18n.t(:awk_rank_pos, :n => rng + 1, :tot => max.to_i + 1)
        end
        t
      end
    rescue StandardError
      nil
    end

    # The ivars come off the class object rather than off an instance, which is why watch_cards holds it.
    def self.mod_ivar(sym)
      k = @cards_class
      k ? (k.instance_variable_get(sym) rescue nil) : nil
    rescue StandardError
      nil
    end

    # Voices affinity points as they are awarded, so the player can tell an answer or a gift landed well.
    #
    # Read from the award call, not from the scene. Scene_HoraDelTe sets @puntos to 0 once at setup and never
    # touches it again -- the running score lives in locals -- so the old reader said "0 affinity points"
    # however the conversation went, and only once, because it hung off `main`, which IS the whole minigame.
    # All three award moments call j_addExp(character, points), which is where the number actually exists,
    # and the character index it carries names the recipient from the game's own card list.
    def self.affinity(pj, pts)
      n = pts.to_i
      return if n == 0
      card = ($Trainer.lista_cartas[pj.to_i] rescue nil)
      who = PokeAccess.clean((card.nombre rescue "").to_s).to_s.strip
      PokeAccess.speak(PokeAccess::I18n.t(:awk_tea, :who => who, :n => n), false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  kernel("j_addExp", :before) { |args, _r| PokeAccess::AwakeningFatesExtra.affinity(args[0], args[1]) }
  override("FatesCartas", :main) do |mod, original, _args|
    PokeAccess::AwakeningFatesExtra.watch_cards(mod)
    begin
      original.call
    ensure
      PokeAccess::AwakeningFatesExtra.unwatch_cards
    end
  end
  poll_each_frame { PokeAccess::AwakeningFatesExtra.cards(nil) }
end
