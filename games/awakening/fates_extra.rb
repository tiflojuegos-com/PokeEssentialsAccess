# Two Fates screens from the CMoon hub: FatesCartas, the relationship cards (a list of panels focused by @posi)
# and the three screens a card opens.
module PokeAccess
  module AwakeningFatesExtra
    @cards_class = nil

    # Holds the FatesCartas class while its main runs (the screen keeps its state on the class), so the frame
    # poll is a nil check the rest of the time.
    def self.watch_cards(klass); @cards_class = klass; end
    def self.unwatch_cards; @cards_class = nil; end

    # The focused card as its panel paints it, keyed by @posi (not @master_index) and by @paneles' identity, which the
    # game rebuilds on every open; the arrow that left and right move leads nowhere and is left unsaid.
    def self.cards(_scene)
      return unless @cards_class
      idx = PokeAccess::AwakeningFatesExtra.mod_ivar(:@posi)
      panels = PokeAccess::AwakeningFatesExtra.mod_ivar(:@paneles)
      return unless idx.is_a?(Integer) && panels.is_a?(Hash)
      panel = panels[idx.to_s]
      return unless panel
      PokeAccess::Cursor.announce(nil, :awk_cards, [idx, panels.__id__], true) { card_line((panel.pj rescue nil)) }
    rescue StandardError
      nil
    end

    # A card's panel as painted: the name, the stars lit of ten, how many of them are dates done, and the date
    # alert the panel draws; nil for a panel with no character.
    def self.card_line(info)
      name = PokeAccess.clean((info.nombre rescue "").to_s)
      return nil if name.empty?
      done = (info.citas_completadas rescue nil) || {}
      shown = (info.rango_visible rescue 0).to_i
      lit = (0...10).count { |i| done[i] || i < shown }
      dates = (0...10).count { |i| done[i] }
      parts = [name, PokeAccess::I18n.t(:awk_card_stars, :n => lit)]
      parts.push(PokeAccess::I18n.t(:awk_prof_dates, :n => dates)) if dates > 0
      parts.push(PokeAccess::I18n.t(:awk_card_alert)) if date_alert?(info)
      parts.join(", ")
    end

    # True when the panel draws its alert: the date of the character's current rank unlocked and not yet done.
    def self.date_alert?(info)
      rank = info.rango_visible
      ::FatesCartas.j_citaDesbloqueada?(info.index, rank) && !::FatesCartas.j_citaCompletada?(info.index, rank)
    rescue StandardError
      false
    end

    # A card's profile (pbLUSperfil) for its place in the trainer's list: its painted fields, the stars lit, the
    # dates done, whether one is waiting and, with hints on, its keys.
    def self.profile(lugar)
      info = ($Trainer.lista_cartas[lugar] rescue nil)
      return nil unless info
      done = (info.citas_completadas || {})
      lit = (0...10).count { |i| done[i] || i < info.rango_visible.to_i }
      parts = [PokeAccess::I18n.t(:awk_prof, :name => info.nombre, :age => info.edad, :title => info.titulo,
                                  :bday => info.cumpleanios, :cls => Array(info.aliados).join(", "),
                                  :loc => info.localidad, :sign => info.signo, :exp => info.exp,
                                  :tot => info.exp_t, :stars => lit)]
      dates = done.values.count { |v| v }
      parts.push(PokeAccess::I18n.t(:awk_prof_dates, :n => dates)) if dates > 0
      ready = (0...10).any? { |i| (::FatesCartas.j_citaDesbloqueada?(info.index, i) && !::FatesCartas.j_citaCompletada?(info.index, i)) rescue false }
      parts.push(PokeAccess::I18n.t(:awk_prof_date_ready)) if ready
      parts.push(PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:awk_prof_keys))) if PokeAccess::Verbosity.hints?
      PokeAccess.clean(parts.join(". "))
    rescue StandardError
      nil
    end

    # The additional information (j_Masinfo): a title and the character's notes, said whole as it opens.
    def self.more_info(lugar)
      notes = Array(($Trainer.lista_cartas[lugar].info rescue nil)).map { |t| PokeAccess.clean(t.to_s) }
      ([PokeAccess::I18n.t(:awk_info_title)] + notes.reject { |t| t.empty? }).join(". ")
    end

    # Opens the level bonuses (j_mostrarResumenNivel), whose cursor is a local: bonus_poll mirrors its keys, and
    # C toggles the focused level's description; a character with none gets the title and that the list is empty.
    def self.bonus_open(pj)
      bonos = (::PersonajesFates.resumen_niveles[pj.index] rescue nil)
      return unless bonos.is_a?(Hash)
      @bonus = { :pj => pj, :bonos => bonos, :levels => bonos.keys.sort, :sel => 0, :info => false }
      title = PokeAccess::I18n.t(:awk_bonus_title, :name => PokeAccess.clean(pj.nombre.to_s))
      row = @bonus[:levels].empty? ? PokeAccess::I18n.t(:list_empty) : bonus_row
      PokeAccess.speak(title + ". " + row, true)
    rescue StandardError
      @bonus = nil
    end

    def self.bonus_close; @bonus = nil; end

    def self.bonus_poll
      b = @bonus
      return unless b
      n = b[:levels].length
      return if n == 0
      if Input.trigger?(Input::UP)
        b[:sel] = (b[:sel] - 1) % n
        b[:info] = false
        PokeAccess.speak(bonus_row, true)
      elsif Input.trigger?(Input::DOWN)
        b[:sel] = (b[:sel] + 1) % n
        b[:info] = false
        PokeAccess.speak(bonus_row, true)
      elsif Input.trigger?(Input::C) || Input.trigger?(Input::A2)
        b[:info] = !b[:info]
        lvl = b[:levels][b[:sel]]
        PokeAccess.speak(b[:info] ? PokeAccess.clean(b[:bonos][lvl][:descripcion].to_s) : bonus_row, true)
      end
    rescue StandardError
      nil
    end

    # The focused level's row as painted, plus whether its date is done (shown only as colour).
    def self.bonus_row
      b = @bonus
      lvl = b[:levels][b[:sel]]
      t = PokeAccess::I18n.t(:awk_bonus_row, :n => lvl, :title => PokeAccess.clean(b[:bonos][lvl][:titulo].to_s))
      done = ((b[:pj].citas_completadas || {})[lvl] rescue false)
      done ? "#{t}, #{PokeAccess::I18n.t(:awk_bonus_done)}" : t
    end

    # An ivar of the watched FatesCartas class, or nil.
    def self.mod_ivar(sym)
      k = @cards_class
      k ? (k.instance_variable_get(sym) rescue nil) : nil
    rescue StandardError
      nil
    end

    # Runs a card's profile (the block, its loop) with the profile said as it opens and the card said again once it
    # closes back onto the list.
    def self.open_profile(lugar)
      PokeAccess.speak(profile(lugar), true)
      begin
        yield
      ensure
        card_back
      end
    end

    # Runs a card's level bonuses (the block, its loop) under bonus_poll, and the card is said again once they
    # close back onto the list.
    def self.open_bonuses(pj)
      bonus_open(pj)
      begin
        yield
      ensure
        bonus_close
        card_back
      end
    end

    # Forgets the focused card, so the list says it again as it reappears behind a closed screen.
    def self.card_back
      PokeAccess::Cursor.reset(nil, :awk_cards)
    end
  end
end

PokeAccess::Game.define("awakening") do
  override("FatesCartas", :main) do |mod, original, _args|
    PokeAccess::AwakeningFatesExtra.watch_cards(mod)
    begin
      original.call
    ensure
      PokeAccess::AwakeningFatesExtra.unwatch_cards
    end
  end
  poll_each_frame { PokeAccess::AwakeningFatesExtra.cards(nil) }
  # The three screens a card opens, each a singleton of FatesCartas running its own loop.
  override("FatesCartas", :pbLUSperfil) do |_mod, original, args|
    PokeAccess::AwakeningFatesExtra.open_profile(args[0]) { original.call }
  end
  override("FatesCartas", :j_Masinfo) do |_mod, original, args|
    PokeAccess.speak(PokeAccess::AwakeningFatesExtra.more_info(args[0]), true)
    original.call
  end
  override("FatesCartas", :j_mostrarResumenNivel) do |_mod, original, args|
    PokeAccess::AwakeningFatesExtra.open_bonuses(args[0]) { original.call }
  end
  poll_each_frame { PokeAccess::AwakeningFatesExtra.bonus_poll }
end
