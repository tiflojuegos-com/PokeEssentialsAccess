module PokeAccess
  # Move-detail wording shared by every move reader (battle, relearner and tutors, summary): power, accuracy and
  # category phrases and the assembled line, from values the caller has already resolved.
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

    # The damage categories in the engines' own numbering, the same in every era: physical, special, status.
    CATEGORIES = [:cat_physical, :cat_special, :cat_status]

    # The spoken word for a category number, or nil for anything that is not one.
    def self.category_word(c)
      c.is_a?(Integer) && CATEGORIES[c] ? PokeAccess::I18n.t(CATEGORIES[c]) : nil
    end

    # The category symbols of the engine Reborn and Rejuvenation share, in the same numbering.
    CATEGORY_SYMS = { :physical => 0, :special => 1, :status => 2 }

    # A move object's id: id everywhere but in the Reborn engine, whose move objects call it move (a symbol).
    def self.id_of(m)
      PokeAccess.attr_of(m, :id, :move)
    end

    # The name and type name a move row paints (the summary's moves page, the fight buttons), given its data's: those
    # unchanged here; a game that paints a move of its own otherwise (Insurgence's custom move) overrides it.
    def self.painted(_m, name, type_name)
      [name, type_name]
    end

    # Whether a move id names a move: not nil, and not the 0 of a gen-6 empty slot.
    def self.real_id?(id)
      return false if id.nil?
      return id != 0 if id.is_a?(Integer)
      !id.to_s.empty?
    end

    # Function codes of the moves whose category depends on the target (Shell Side Arm, Photon Geyser).
    TARGET_CATEGORY = ["CategoryDependsOnHigherDamagePoisonTarget", "CategoryDependsOnHigherDamageIgnoreTargetAbility"]

    # The category such a move is drawn with, worked out on a copy against the foe ahead; nil for other moves.
    def self.target_category(move, battler)
      return nil unless TARGET_CATEGORY.include?((move.function_code rescue nil))
      m = (move.clone rescue move)
      m.pbOnStartUse(battler, [battler.pbDirectOpposing])
      c = m.calcCategory
      c.is_a?(Integer) ? c : nil
    rescue StandardError
      nil
    end

    # The category number of a move object: its own answer where it has one (a battle move, which the
    # battle can change), the gen-6 battle move's @category (kept without a reader), else the move data by id.
    def self.category_of(m)
      c = (m.category rescue nil)
      c = PokeAccess.ivar(m, :@category) unless c.is_a?(Integer) || c.is_a?(Symbol)
      c = PokeAccess::Data.move_category(id_of(m)) unless c.is_a?(Integer) || c.is_a?(Symbol)
      c = CATEGORY_SYMS[c] if c.is_a?(Symbol)
      c.is_a?(Integer) ? c : nil
    rescue StandardError
      nil
    end

    # The spoken detail line for a move id resolved through GameData (v21 and v22), or nil when it does not resolve.
    # param reading the verbosity reading the line is said as (see leveled); nil for the whole line
    def self.by_id(id, reading = nil)
      data = (GameData::Move.get(id) rescue nil)
      return nil unless data
      ty = (GameData::Type.get(data.type).name rescue nil)
      nm = (data.name rescue PokeAccess::I18n.t(:info_move)).to_s
      pw = PokeAccess.attr_of(data, :power, :base_damage)
      leveled(reading, nm, ty, pw || 0, (data.accuracy rescue 0), :cat => category_word((data.category rescue nil)),
              :desc => (data.description rescue ""))
    rescue StandardError
      nil
    end

    # As by_id, through the per-engine Data adapter (gen 6 included), with the total pp; nil when the id has no name.
    def self.by_id_via_data(id, reading = nil)
      nm = (PokeAccess::Data.move_name(id) rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      ty = (PokeAccess::Data.move_type_name(id) rescue nil)
      pw = (PokeAccess::Data.move_power(id) rescue 0)
      acc = (PokeAccess::Data.move_accuracy(id) rescue 0)
      desc = (PokeAccess::Data.move_description(id) rescue "")
      tot = (PokeAccess::Data.move_total_pp(id) rescue nil)
      tot = nil unless tot.is_a?(Integer) && tot > 0
      leveled(reading, nm.to_s, ty, pw, acc, :cat => category_word((PokeAccess::Data.move_category(id) rescue nil)),
              :pp => tot, :total_pp => tot, :desc => desc)
    rescue StandardError
      nil
    end

    # Reading => the level each part of a move line is said from; the name always goes.
    PART_LEVELS = {
      :battle_move  => { :type => :medium, :cat => :full, :power => :full, :acc => :full, :pp => :brief, :desc => :full },
      :summary_move => { :type => :medium, :cat => :full, :power => :full, :acc => :full, :pp => :brief, :desc => :full },
      :learn_move   => { :type => :medium, :cat => :full, :power => :full, :acc => :full, :pp => :full, :desc => :full }
    }

    # line at a reading's level, the parts it does not reach left out; with no reading, the whole line.
    def self.leveled(reading, name, type_name, power, accuracy, opts = {})
      return line(name, type_name, power, accuracy, opts) if reading.nil?
      from = PART_LEVELS[reading] || {}
      keep = lambda { |part| PokeAccess::Verbosity.keep?(reading, from[part] || :full) }
      line(name, keep.call(:type) ? type_name : nil, keep.call(:power) ? power : nil,
           keep.call(:acc) ? accuracy : nil,
           :cat => (keep.call(:cat) ? opts[:cat] : nil), :pp => (keep.call(:pp) ? opts[:pp] : nil),
           :total_pp => opts[:total_pp], :desc => (keep.call(:desc) ? opts[:desc] : nil))
    end

    # Assembles "name. type[. category]. power. accuracy[. pp][. description]"; a nil part is left out, :pp needs
    # :total_pp too, and only a real 0 power or accuracy says "no damage" or "never misses".
    def self.line(name, type_name, power, accuracy, opts = {})
      s = name.to_s
      s += ". " + PokeAccess::I18n.t(:mv_type, :t => type_name) if type_name && !type_name.to_s.empty?
      cat = opts[:cat]
      s += ". " + cat.to_s if cat && !cat.to_s.empty?
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
