module PokeAccess
  # Contextual info for the info key (move / item / pokemon / trainer / battle foe).
  module Info
    # Stores what the info key should read next. param kind one of :move/:item/:pokemon/:trainer/
    # :battle_foe/:text (a ready string)
    def self.set_info(kind, data)
      @kind = kind
      @data = data
    end

    # Clears combat-only info (move/foe/text) so the info key stops reading a stale battle line on the
    # map; field info (:pokemon/:item/:trainer) is kept.
    def self.clear_combat
      @kind = nil if @kind == :move || @kind == :battle_foe || @kind == :text
    end

    # Builds the text for the currently stored info kind.
    def self.info_text
      case @kind
      when :move       then move_info(@data)
      when :item       then item_info(@data)
      when :pokemon    then pokemon_info(@data)
      when :trainer    then trainer_info
      when :battle_foe then PokeAccess::Battle.foe_info
      when :text       then @data
      else nil
      end
    rescue StandardError
      nil
    end

    #builders

    # Describes a move: type, power, accuracy, pp and description. This method only RESOLVES the fields
    # (from the move object, falling back to PokeAccess::Data per field); the spoken assembly and the
    # power/accuracy wording are MoveInfo.line's, the single assembler -- this was the divergent copy that
    # treated accuracy 0 differently and skipped the no-power phrasing. Total pp answers to either
    # engine's name (totalpp gen-6, total_pp modern).
    def self.move_info(m)
      return nil unless m
      mid  = (m.id rescue nil)
      bd   = (m.basedamage rescue nil); bd  = PokeAccess::Data.move_power(mid) if bd.nil?
      acc  = (m.accuracy rescue nil);   acc = PokeAccess::Data.move_accuracy(mid) if acc.nil?
      name = (m.name rescue nil); name = (PokeAccess::Data.move_name(mid) || PokeAccess::I18n.t(:info_move)) if name.nil? || name.to_s.empty?
      pp   = (m.pp rescue nil)
      tot  = (m.totalpp rescue nil); tot = (m.total_pp rescue nil) if tot.nil?
      desc = PokeAccess::Data.move_description(mid)
      ty   = (m.type rescue nil)
      tipo = ty ? (PokeAccess::Data.type_name(ty) rescue nil) : nil
      tipo = PokeAccess::Data.move_type_name(mid) if tipo.nil? || tipo.to_s.empty?
      PokeAccess::MoveInfo.line(name.to_s, tipo, bd, acc, :pp => pp, :total_pp => tot, :desc => desc)
    rescue StandardError
      (PokeAccess::Data.move_name((m.id rescue 0)) || PokeAccess::I18n.t(:info_move))
    end

    # Describes an item: name and description. A screen (the bag) can supply the exact text via
    # note_item_desc, else it is resolved through PokeAccess::Data (which some games leave empty -> only
    # the name). A TM/HM also reads the move it teaches -- the datum a blind player most needs from a
    # machine -- resolved per era: gen-6 through $ItemData, GameData through GameData::Item#move (v19+).
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
      parts.join(". ")
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

    # Remembers the description a screen's adapter supplies (the game's exact source), tied to the item
    # id, so the info key reads what the screen shows even if the generic lookups miss it.
    def self.note_item_desc(id, desc); @idesc = (desc && !desc.to_s.empty?) ? [id, desc] : nil; end

    # The remembered description if it is for this item, else nil.
    def self.noted_item_desc(id); (@idesc && @idesc[0] == id) ? @idesc[1] : nil; end

    # Describes a party pokemon at a glance: name, level, hp, gender, held item and status.
    def self.pokemon_info(pk)
      return nil unless pk
      t = PokeAccess::I18n.t(:pk_glance, :name => pk.name, :level => pk.level, :hp => pk.hp, :tot => pk.totalhp)
      w = PokeAccess::Party.gender_word(pk); t += " #{w}." if w
      itm = (pk.item rescue nil)
      if itm && itm != 0
        it = itm.respond_to?(:name) ? (itm.name rescue nil) : PokeAccess::Data.item_name(itm)
        t += " #{PokeAccess::I18n.t(:pk_holds, :item => it)}." if it && !it.to_s.empty?
      end
      st = (pk.status rescue nil)
      unless st.nil? || st == 0 || st == :NONE
        sn = PokeAccess::Data.status_name(st)
        t += " #{PokeAccess::I18n.t(sn)}." if sn && !sn.to_s.empty?
      end
      t
    end

    # The full pokemon data sheet: species, types, nature, ability, item and six stats.
    def self.summary_text(pk)
      return nil unless pk
      t = PokeAccess::I18n.t(:sum_data_of, :name => (pk.name rescue "?"), :level => (pk.level rescue "?")) + " "
      sp = PokeAccess::Data.species_name(pk.species); t += PokeAccess::I18n.t(:sum_species, :s => sp) + " " if sp
      ty = PokeAccess::Data.pokemon_types(pk)
      t += PokeAccess::I18n.t(:sum_type, :t => ty.join(' ')) + " " unless ty.empty?
      nat = PokeAccess::Data.nature_name(pk.nature); t += PokeAccess::I18n.t(:sum_nature, :n => nat) + " " if nat
      ab  = PokeAccess::Data.ability_name(pk.ability); t += PokeAccess::I18n.t(:sum_ability, :a => ab) + " " if ab && !ab.to_s.empty?
      if (pk.item rescue 0) != 0
        it = PokeAccess::Data.item_name(pk.item); t += PokeAccess::I18n.t(:sum_item, :i => it) + " " if it
      end
      stats = (PokeAccess::I18n.t(:sum_stats, :hp => pk.hp, :tot => pk.totalhp, :atk => pk.attack,
                                  :def => pk.defense, :spa => pk.spatk, :spd => pk.spdef, :spe => pk.speed) rescue nil)
      t += stats if stats
      t
    rescue StandardError
      nil
    end

    # Resolves a move by id on a pokemon and describes it, also storing it for the info key.
    def self.move_by_id_info(pk, moveid)
      m = (pk.moves.detect { |mv| mv && mv.id == moveid } rescue nil)
      if m
        set_info(:move, m)
        move_info(m)
      else
        move_info_by_id(moveid)
      end
    end

    # Describes a move from its id alone (the move being learned on the forget screen, or any move known
    # only by id): on gen-6 it builds a PBMove and reads it through move_info; elsewhere it speaks the name.
    def self.move_info_by_id(moveid)
      return nil unless moveid && moveid.to_i != 0
      m = (PBMove.new(moveid) rescue nil)
      if m
        set_info(:move, m)
        move_info(m)
      else
        (PokeAccess::Data.move_name(moveid) || PokeAccess::I18n.t(:info_move))
      end
    end

    # Describes the trainer: name, money, badges, pokedex and play time. Dispatched on which player global
    # the engine exposes ($player => the modern reader, else gen-6 $Trainer), not on a version flag.
    def self.trainer_info
      return gamedata_trainer_info if defined?($player) && $player
      return nil unless defined?($Trainer) && $Trainer
      parts = ["#{$Trainer.name}"]
      money = ($Trainer.money rescue nil)
      parts.push(PokeAccess::I18n.t(PokeAccess::Config.money_label, :n => money)) if money
      badges = PokeAccess::Util.badge_count($Trainer)
      parts.push(PokeAccess::I18n.t(:tr_badges, :n => badges)) if badges
      if ($Trainer.pokedex rescue false)
        seen = ($Trainer.pokedexSeen rescue nil)
        own  = ($Trainer.pokedexOwned rescue nil)
        parts.push(PokeAccess::I18n.t(:tr_pokedex, :owned => own, :seen => seen)) if seen && own
      end
      if $PokemonGlobal && $PokemonGlobal.respond_to?(:playTime)
        hm = PokeAccess::Util.playtime_parts(($PokemonGlobal.playTime.to_i rescue 0))
        parts.push(PokeAccess::I18n.t(:tr_playtime, :h => hm[0], :m => hm[1])) if hm
      end
      parts.join(". ")
    rescue StandardError
      nil
    end

    # GameData-era ($player) trainer summary: name, money, badges, pokedex tally and play time. Used when
    # $Trainer is absent (Essentials v17+).
    def self.gamedata_trainer_info
      p = ($player rescue nil)
      return nil unless p
      parts = ["#{p.name}"]
      money = (p.money rescue nil)
      parts.push(PokeAccess::I18n.t(PokeAccess::Config.money_label, :n => money)) if money
      badges = PokeAccess::Util.badge_count(p)
      parts.push(PokeAccess::I18n.t(:tr_badges, :n => badges)) if badges
      dex = (p.pokedex rescue nil)
      if dex && (dex.respond_to?(:owned_count) rescue false)
        parts.push(PokeAccess::I18n.t(:tr_pokedex, :owned => dex.owned_count, :seen => dex.seen_count))
      end
      hm = PokeAccess::Util.playtime_parts(($stats.play_time.to_i rescue nil))
      parts.push(PokeAccess::I18n.t(:tr_playtime, :h => hm[0], :m => hm[1])) if hm
      parts.join(". ")
    rescue StandardError
      nil
    end
  end
end

# When battle ends, drop combat-only info so the info key does not re-read a stale battle line on the map.
PokeAccess::Hooks.after_hook("Game_Temp", :in_battle=) do |_t, _r, args|
  PokeAccess::Info.clear_combat unless args[0]
end
