module PokeAccess
  # What the info key reads: the focused move, item, Pokemon, trainer or foe, or a ready line; and, with Ctrl, the
  # focused row whole.
  module Info
    # Stores what the info key reads next and the focused row for Ctrl+T.
    # param kind one of :move/:item/:pokemon/:trainer/:battle_foe/:text (a ready string)
    # param row the focused row as the full level says it, or nil where the screen has none
    def self.set_info(kind, data, row = nil)
      @kind = kind
      @data = data
      @row = row
      @row_windows = []
    end

    # Adds a standing window that belongs to the focused row (a shop's count in the bag) to what Ctrl+T says, until
    # the next set_info; one text per slot.
    def self.add_to_row(text, slot)
      return if text.nil? || text.to_s.strip.empty?
      @row_windows ||= []
      return if @row_windows.include?([slot, text.to_s])
      @row_windows = @row_windows.reject { |r| r[0] == slot }
      @row_windows.push([slot, text.to_s])
    end

    # What Ctrl+T says: the focused row whole and its windows, or nil where the screen published no row.
    def self.row_text
      return nil if @row.nil? || @row.to_s.strip.empty?
      PokeAccess.sentences([@row].concat((@row_windows || []).map { |r| r[1] }))
    end

    # Forgets the battle's info (move, foe, ready line) when the fight ends; field info stays.
    def self.clear_combat
      set_info(nil, nil) if @kind == :move || @kind == :battle_foe || @kind == :text
    end

    # Forgets a ready line when the screen that published it closes; a Pokemon or an item stays.
    def self.clear_text
      set_info(nil, nil) if @kind == :text
    end

    # The text of the stored info.
    def self.info_text
      case @kind
      when :move       then move_info(@data)
      when :item       then item_info(@data)
      when :pokemon    then pokemon_info(@data)
      when :trainer    then trainer_info
      when :battle_foe then PokeAccess::Battle.foe_info
      when :text       then @data
      end
    rescue StandardError
      nil
    end

    #builders

    # Describes a move: type, category, power, accuracy, pp and description, each field from the move object or
    # else PokeAccess::Data; the wording is MoveInfo.leveled's.
    # param reading the verbosity reading a screen says it as; nil (the info key) for the whole line
    def self.move_info(m, reading = nil)
      return nil unless m
      mid  = PokeAccess::MoveInfo.id_of(m)
      bd   = (m.basedamage rescue nil); bd  = PokeAccess::Data.move_power(mid) if bd.nil?
      acc  = (m.accuracy rescue nil);   acc = PokeAccess::Data.move_accuracy(mid) if acc.nil?
      name = (m.name rescue nil); name = (PokeAccess::Data.move_name(mid) || PokeAccess::I18n.t(:info_move)) if name.nil? || name.to_s.empty?
      pp   = (m.pp rescue nil)
      tot  = PokeAccess.attr_of(m, :totalpp, :total_pp)
      desc = PokeAccess::Data.move_description(mid)
      ty   = (m.type rescue nil)
      tipo = ty ? (PokeAccess::Data.type_name(ty) rescue nil) : nil
      tipo = PokeAccess::Data.move_type_name(mid) if tipo.nil? || tipo.to_s.empty?
      cat = PokeAccess::MoveInfo.category_word(PokeAccess::MoveInfo.category_of(m))
      PokeAccess::MoveInfo.leveled(reading, name.to_s, tipo, bd, acc, :cat => cat, :pp => pp, :total_pp => tot, :desc => desc)
    rescue StandardError
      (PokeAccess::Data.move_name(PokeAccess::MoveInfo.id_of(m)) || PokeAccess::I18n.t(:info_move))
    end

    # Describes an item: name and description (the one a screen noted, else PokeAccess::Data's), plus the move a
    # TM/HM teaches.
    def self.item_info(itemid)
      name = item_name_for(itemid)
      desc = noted_item_desc(itemid) || item_desc_for(itemid)
      parts = [name, desc].reject { |x| x.nil? || x.to_s.strip.empty? }
      mv = machine_move(itemid)
      if mv
        mname = PokeAccess::Data.move_name(mv)
        mdesc = PokeAccess::Data.move_description(mv)
        parts.push(PokeAccess::I18n.t(:it_teaches, :move => mname) + ". #{mdesc}") if mname
      end
      PokeAccess.sentences(parts)
    end

    # The move a TM/HM/TR teaches, or nil for a normal item, on either era.
    def self.machine_move(itemid)
      if (pbIsMachine?(itemid) rescue false)
        mv = ($ItemData[itemid][ITEMMACHINE] rescue 0)
        return mv if mv && (!mv.respond_to?(:>) || mv > 0)
      end
      if defined?(GameData) && defined?(GameData::Item)
        it = (GameData::Item.get(itemid) rescue nil)
        mv = (it && it.respond_to?(:move) ? it.move : nil)
        return mv if mv
      end
      nil
    rescue StandardError
      nil
    end

    # The item name, via the engine's data provider.
    def self.item_name_for(itemid)
      PokeAccess::Data.item_name(itemid)
    end

    # The item description, via the engine's data provider (empty reads as nil so a caller can fall back).
    def self.item_desc_for(itemid)
      d = PokeAccess::Data.item_description(itemid)
      (d && !d.to_s.empty?) ? d : nil
    end

    # Remembers the description a screen shows for an item id, read ahead of the generic lookup.
    def self.note_item_desc(id, desc); @idesc = (desc && !desc.to_s.empty?) ? [id, desc] : nil; end

    # The remembered description if it is for this item, else nil.
    def self.noted_item_desc(id); (@idesc && @idesc[0] == id) ? @idesc[1] : nil; end

    # Describes a party pokemon at a glance: name, level, hp, the marks its panel draws, gender, held item and
    # status; an egg is only "egg", as its panel shows it. An item kept as a symbol is named through the data, since
    # on Ruby 3 the symbol's own name is the id.
    def self.pokemon_info(pk)
      return nil unless pk
      return PokeAccess::I18n.t(:pty_egg) if PokeAccess::Summary.egg?(pk)
      t = PokeAccess::I18n.t(:pk_glance, :name => pk.name, :level => pk.level, :hp => pk.hp, :tot => pk.totalhp)
      marks = PokeAccess::Party.icon_mark_list(pk) + PokeAccess::Party.panel_marks(pk)
      t += " #{marks.join(', ')}." unless marks.empty?
      g = PokeAccess::Party.gender_glyph(pk); t += " #{g}." if g
      itm = (pk.item rescue nil)
      if itm && itm != 0
        it = (!itm.is_a?(Symbol) && itm.respond_to?(:name)) ? (itm.name rescue nil) : PokeAccess::Data.item_name(itm)
        t += " #{PokeAccess::I18n.t(:pk_holds, :item => it)}." if it && !it.to_s.empty?
      end
      st = (pk.status rescue nil)
      unless st.nil? || st == 0 || st == :NONE
        sn = PokeAccess::Data.status_name(st)
        t += " #{PokeAccess::I18n.t(sn)}." if sn && !sn.to_s.empty?
      end
      t
    end

    # The full pokemon data sheet: name and sex sign, header icons, dex number, species, types, nature, ability,
    # item and six stats, then the first page's trainer lines (original trainer, ID, experience, next level).
    def self.summary_text(pk, dex = nil)
      return nil unless pk
      nm = "#{(pk.name rescue "?")}#{PokeAccess::Party.sign_phrase(pk)}"
      t = PokeAccess::I18n.t(:sum_data_of, :name => nm, :level => (pk.level rescue "?")) + " "
      icons = PokeAccess::Summary.header_icons(pk)
      t += "#{icons}. " unless icons.empty?
      t += PokeAccess::I18n.t(:sum_dex, :n => dex) + " " if dex
      sp = PokeAccess::Data.species_name(pk.species); t += PokeAccess::I18n.t(:sum_species, :s => sp) + " " if sp
      ty = PokeAccess::Data.pokemon_types(pk)
      t += PokeAccess::I18n.t(:sum_type, :t => ty.join(' ')) + " " unless ty.empty?
      nat = PokeAccess::Data.nature_name(pk.nature); t += PokeAccess::I18n.t(:sum_nature, :n => nat) + " " if nat
      ab  = PokeAccess::Data.ability_name(pk.ability); t += PokeAccess::I18n.t(:sum_ability, :a => ab) + " " if ab && !ab.to_s.empty?
      t += PokeAccess::Summary.item_fact(pk) + " "
      stats = (PokeAccess::I18n.t(:sum_stats, :hp => pk.hp, :tot => pk.totalhp, :atk => pk.attack,
                                  :def => pk.defense, :spa => pk.spatk, :spd => pk.spdef, :spe => pk.speed) rescue nil)
      t += stats if stats
      facts = PokeAccess::Summary.trainer_facts(pk)
      t += " " + facts.join(" ") unless facts.empty?
      t
    rescue StandardError
      nil
    end

    # Resolves a move by id on a pokemon and describes it, also storing it for the info key.
    # param reading the verbosity reading the screen says it as; nil for the whole line
    def self.move_by_id_info(pk, moveid, reading = nil)
      m = (pk.moves.detect { |mv| mv && PokeAccess::MoveInfo.id_of(mv) == moveid } rescue nil)
      if m
        set_info(:move, m)
        move_info(m, reading)
      else
        move_info_by_id(moveid, reading)
      end
    end

    # Describes a move known only by id, storing it for the info key: through a PBMove (gen-6), else just its name.
    def self.move_info_by_id(moveid, reading = nil)
      return nil unless moveid && moveid.to_i != 0
      m = (PBMove.new(moveid) rescue nil)
      if m
        set_info(:move, m)
        move_info(m, reading)
      else
        (PokeAccess::Data.move_name(moveid) || PokeAccess::I18n.t(:info_move))
      end
    end

    # The named parts of the trainer line (info key and trainer card): each takes the player object and answers a
    # fragment or nil. The order is Config.trainer_parts; a profile swaps or adds one with set_trainer_part.
    TRAINER_PARTS = {
      :name     => lambda { |tr| tr.name.to_s },
      :money    => lambda { |tr|
        m = (tr.money rescue nil)
        m.nil? ? nil : PokeAccess::I18n.t(PokeAccess::Config.money_label, :n => m)
      },
      :badges   => lambda { |tr|
        n = PokeAccess::Util.badge_count(tr)
        n.nil? ? nil : PokeAccess::I18n.t(:tr_badges, :n => n)
      },
      :pokedex  => lambda { |tr| PokeAccess::Info.pokedex_tally(tr) },
      :playtime => lambda { |_tr|
        hm = PokeAccess::Util.playtime_parts(PokeAccess::Util.playtime_seconds)
        hm ? PokeAccess::I18n.t(:tr_playtime, :h => hm[0], :m => hm[1]) : nil
      }
    }

    # The player object the engine exposes: $player (GameData era) else gen-6 $Trainer, nil before a game.
    def self.player_object
      return $player if defined?($player) && $player
      return $Trainer if defined?($Trainer) && $Trainer
      nil
    end

    # The Pokedex tally fragment: v19+ keeps the counts on a Pokedex object, gen-6 on the trainer itself
    # behind a boolean pokedex flag.
    def self.pokedex_tally(tr)
      dex = (tr.pokedex rescue nil)
      return nil unless dex
      if (dex.respond_to?(:owned_count) rescue false)
        return PokeAccess::I18n.t(:tr_pokedex, :owned => dex.owned_count, :seen => dex.seen_count)
      end
      seen = (tr.pokedexSeen rescue nil)
      own  = (tr.pokedexOwned rescue nil)
      (seen && own) ? PokeAccess::I18n.t(:tr_pokedex, :owned => own, :seen => seen) : nil
    end

    # Describes the trainer: the configured parts, in order, those that answered.
    def self.trainer_info
      tr = player_object
      return nil unless tr
      parts = PokeAccess::Config.trainer_parts.map { |key| trainer_part(key, tr) }.compact
      parts.empty? ? nil : parts.join(". ")
    rescue StandardError
      nil
    end

    # One named part, rescued on its own: a reader that fails costs its fragment, not the line.
    def self.trainer_part(key, tr)
      reader = TRAINER_PARTS[key]
      return nil unless reader
      t = reader.call(tr)
      (t.nil? || t.to_s.empty?) ? nil : t.to_s
    rescue StandardError
      nil
    end

    # Defines or replaces a named part (the block gets the player object); a new name joins the end of the order.
    def self.set_trainer_part(key, &reader)
      TRAINER_PARTS[key] = reader
      order = PokeAccess::Config.trainer_parts
      order.push(key) unless order.include?(key)
      key
    end
  end
end

# When the battle ends, drops the battle-only info.
PokeAccess::Hooks.after_hook("Game_Temp", :in_battle=) do |_t, _r, args|
  PokeAccess::Info.clear_combat unless args[0]
end
