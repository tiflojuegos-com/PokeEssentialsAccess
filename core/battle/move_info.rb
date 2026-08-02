module PokeAccess
  # Shared move-detail formatting used by every move reader (battle, the relearner and egg-move tutors, the
  # summary moves page). Centralises the power/accuracy wording -- the one spot where divergent copies used
  # to disagree (a power-1 "variable" move once read as "no damage" in battle) -- and assembles the spoken
  # line. Callers resolve type/power/accuracy from whatever source fits their screen (plain move data,
  # display_* for a specific pokemon, or an in-battle clone) and pass the resolved values in.
  module MoveInfo
    # The spoken power: "no damage" at 0 or below, "variable" at 1 (fixed-damage / level-based moves), else
    # the numeric value.
    def self.power_phrase(pw)
      n = pw.to_i
      return PokeAccess::I18n.t(:mv_power_none) if n <= 0
      return PokeAccess::I18n.t(:mv_power_var) if n == 1
      n.to_s
    end

    # The spoken accuracy: "never misses" at 0 or below (the engine's "always hits" sentinel), else the value.
    def self.accuracy_phrase(acc)
      acc.to_i <= 0 ? PokeAccess::I18n.t(:mv_acc_perfect) : acc.to_i
    end

    # The spoken detail for a move id (symbol/integer) resolved through GameData -- name, type, power,
    # accuracy and description. Engine-agnostic (GameData is the modern data system shared by v21 and v22),
    # so both readers use this instead of one version importing from another. nil when the id does not
    # resolve.
    def self.by_id(id)
      data = (GameData::Move.get(id) rescue nil)
      return nil unless data
      ty = (GameData::Type.get(data.type).name rescue nil)
      nm = (data.name rescue PokeAccess::I18n.t(:info_move)).to_s
      line(nm, ty, (data.power rescue 0), (data.accuracy rescue 0), :desc => (data.description rescue ""))
    rescue StandardError
      nil
    end

    # The spoken detail for a move id resolved through the per-engine Data adapter (PBMoveData on gen-6,
    # GameData on modern) rather than GameData directly, so a gen-6 reader gets the full line too. nil when
    # the id resolves to nothing. Used by the gen-6 move relearner, whose ids are plain PBMove integers.
    def self.by_id_via_data(id)
      nm = (PokeAccess::Data.move_name(id) rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      ty = (PokeAccess::Data.move_type_name(id) rescue nil)
      pw = (PokeAccess::Data.move_power(id) rescue 0)
      acc = (PokeAccess::Data.move_accuracy(id) rescue 0)
      desc = (PokeAccess::Data.move_description(id) rescue "")
      line(nm.to_s, ty, pw, acc, :desc => desc)
    rescue StandardError
      nil
    end

    # Assembles "name. type. power. accuracy[. pp][. description]" from already-resolved parts. Options:
    # :pp and :total_pp (both required to speak pp), :desc (appended when present and non-blank). A nil
    # power/accuracy means UNRESOLVED and omits its phrase -- only a real 0 speaks "no damage"/"never
    # misses"; callers with partial data stay honest instead of guessing.
    def self.line(name, type_name, power, accuracy, opts = {})
      s = name.to_s
      s += ". " + PokeAccess::I18n.t(:mv_type, :t => type_name) if type_name && !type_name.to_s.empty?
      s += ". " + PokeAccess::I18n.t(:mv_power, :p => power_phrase(power)) unless power.nil?
      s += ". " + PokeAccess::I18n.t(:mv_acc, :a => accuracy_phrase(accuracy)) unless accuracy.nil?
      pp = opts[:pp]; tot = opts[:total_pp]
      s += ". " + PokeAccess::I18n.t(:mv_pp, :pp => pp, :tot => tot) if pp && tot
      desc = opts[:desc]
      s += ". " + desc.to_s if desc && !desc.to_s.empty?
      s
    end
  end
end
