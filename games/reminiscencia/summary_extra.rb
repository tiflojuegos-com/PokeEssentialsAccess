module PokeAccess
  # Reminiscencia's summary (PScreen_Summary_NEW) is its detailed STATUS screen, redrawn by drawPageOne on
  # every key: left/right switch pokemon, 1-4 focus a move (@infomove/@chosenmove), T the ability
  # (@infohab), A reads the focused description via a normal message (caught by the dialogue hook). On open
  # and on switching pokemon it reads the full status; deduped so an unchanged redraw stays silent. It owns
  # the summary voice here (Summary.single_page suppresses the generic core read). Labels are ASCII.
  module RemiSummary
    # PBStats order is HP=0, ATTACK=1, DEFENSE=2, SPEED=3, SPATK=4, SPDEF=5; the screen lists them as
    # STAT_ORDER (PS, Ataque, Defensa, At. Esp., Def. Esp., Velocidad).
    STAT_LABELS = ["PS", "Ataque", "Defensa", "Velocidad", "At. Esp.", "Def. Esp."]
    STAT_ORDER  = [0, 1, 2, 4, 5, 3]
    # Scene bonus ivar per PBStats index (Reminiscencia's per-species stat bonus, shown as a %).
    BONUS_IVARS = { 0 => :@bonusHP, 1 => :@bonusATK, 2 => :@bonusDEF,
                    3 => :@bonusSPD, 4 => :@bonusSPATK, 5 => :@bonusSPDEF }

    # The spoken text for the scene's current state, or nil when nothing relevant changed.
    def self.text(scene)
      pk = PokeAccess.ivar(scene, :@pokemon)
      return nil unless pk
      info_move = (scene.instance_variable_get(:@infomove) rescue false) ? true : false
      info_hab  = (scene.instance_variable_get(:@infohab) rescue false) ? true : false
      cm = (scene.instance_variable_get(:@chosenmove) rescue 0)
      key = [pk.object_id, info_move, info_hab, info_move ? cm : nil]
      return nil unless PokeAccess::Cursor.changed?(scene, :sumkey, key)
      return focused_move(pk, cm) if info_move
      return ability_text(pk) if info_hab
      estado(scene, pk)
    rescue StandardError
      nil
    end

    # The detail of the focused move (1-4), or a note when the slot is empty.
    def self.focused_move(pk, cm)
      m = (pk.moves[cm] rescue nil)
      (m && m.id && m.id.to_i != 0) ? PokeAccess::Info.move_by_id_info(pk, m.id) : "Sin movimiento"
    end

    # The ability name (its description is read by the game's own A key, via a message).
    def self.ability_text(pk)
      ab = (PBAbilities.getName(pk.ability) rescue nil)
      (ab && !ab.to_s.empty?) ? "Habilidad #{ab}. Pulsa A para la descripcion." : "Sin habilidad"
    end

    # The full status sheet: name, species, types, nature, condition, the six stats with IVs, EVs and
    # bonus, then ability, item and moves. Read on open and when switching pokemon.
    def self.estado(scene, pk)
      parts = []
      sp = (PBSpecies.getName(pk.species) rescue nil)
      ty = (PokeAccess::Data.pokemon_types(pk) rescue [])
      head = "#{(pk.name rescue '?')}, nivel #{(pk.level rescue '?')}"
      head += ", #{sp}" if sp && !sp.to_s.empty?
      head += ", tipo #{ty.join(' ')}" unless ty.empty?
      parts.push(head)
      nat = (PBNatures.getName(pk.nature) rescue nil)
      parts.push("Naturaleza #{nat}") if nat && !nat.to_s.empty?
      cond = status_phrase(pk); parts.push(cond) if cond
      sv = (stat_values(pk) rescue nil); parts.push(stat_line("Estadisticas", sv)) if sv
      iv = (pk.iv rescue nil); parts.push(stat_line("IVs", iv)) if iv.is_a?(Array)
      ev = (pk.ev rescue nil); parts.push(stat_line("EVs", ev)) if ev.is_a?(Array)
      bon = bonus_values(scene); parts.push(stat_line("Bonus", bon, "%")) if bon
      ab = (PBAbilities.getName(pk.ability) rescue nil)
      parts.push("Habilidad #{ab}") if ab && !ab.to_s.empty?
      if (pk.item rescue 0) != 0
        it = (PBItems.getName(pk.item) rescue nil)
        parts.push("Objeto #{it}") if it && !it.to_s.empty?
      end
      mv = (PokeAccess::Summary.moves_text(pk) rescue nil); parts.push(mv) if mv
      parts.join(". ")
    end

    # One spoken line of the six stats in screen order, each label followed by its value. param title the
    # line heading (Estadisticas / IVs / EVs / Bonus); param suffix appended to each value (e.g. "%")
    def self.stat_line(title, vals, suffix = "")
      stats = STAT_ORDER.map { |i| "#{STAT_LABELS[i]} #{vals[i]}#{suffix}" }.join(", ")
      "#{title}. #{stats}"
    end

    # The current value of each stat, by PBStats index (HP shown as current of max).
    def self.stat_values(pk)
      { 0 => "#{pk.hp} de #{pk.totalhp}", 1 => pk.attack, 2 => pk.defense,
        3 => pk.speed, 4 => pk.spatk, 5 => pk.spdef }
    end

    # The per-species stat bonus the screen shows, by PBStats index, or nil when all zero/absent.
    def self.bonus_values(scene)
      h = {}
      BONUS_IVARS.each do |stat, ivar|
        h[stat] = (scene.instance_variable_get(ivar) rescue nil).to_i
      end
      h.values.any? { |v| v != 0 } ? h : nil
    rescue StandardError
      nil
    end

    # The condition status: fainted, or sleep/poison/burn/paralysis/freeze via the shared table.
    def self.status_phrase(pk)
      return "Debilitado" if (pk.hp rescue 1).to_i == 0
      st = (pk.status rescue 0)
      return nil if st.nil? || st == 0
      sn = (PokeAccess::Config.status_names[st] rescue nil)
      sn ? PokeAccess::I18n.t(sn) : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Summary.single_page = true

# Reads the summary state on each redraw (deduped inside RemiSummary.text).
PokeAccess::Game.define("reminiscencia") do
  after("PokemonSummaryScene", :drawPageOne) do |scene, _r, _a|
    t = PokeAccess::RemiSummary.text(scene)
    PokeAccess.speak(t, true) if t && !t.to_s.empty?
  end
end
