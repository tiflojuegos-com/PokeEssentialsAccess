module PokeAccess
  # Data provider of the engine Reborn, Rejuvenation and Desolation share: no GameData and no PB* name tables, but a
  # $cache of data objects keyed by symbol and the game's own get*Name helpers over it, which go through the game's
  # translations where it has them. Registered above gen-6 when $cache answers those tables. Resolvers stay raw.
  module DataRV
    # Status symbols => the i18n keys of the gen-6 status words; PETRIFIED is the engine's own.
    STATUS_KEYS = { :SLEEP => :st_sleep, :POISON => :st_poison, :BURN => :st_burn, :PARALYSIS => :st_paralysis,
                    :FROZEN => :st_freeze, :PETRIFIED => :st_petrified }

    # PBStats numbers (HP, Attack, Defense, Sp. Atk, Sp. Def, Speed, accuracy, evasion) => i18n key.
    STAT_KEYS = [:st_hp, :st_atk, :st_def, :st_spatk, :st_spdef, :st_speed, :st_accuracy, :st_evasion]

    # True when the running engine keeps its data in such a $cache, and has no GameData.
    def self.engine?
      return false if defined?(GameData)
      c = $cache
      (c && c.respond_to?(:pkmn) && c.respond_to?(:moves) && c.respond_to?(:abil)) ? true : false
    rescue StandardError
      false
    end

    # The text, or nil when the game answered with an empty string (its helpers' "not found").
    def self.present(text)
      (text.nil? || text.to_s.empty?) ? nil : text
    end

    def self.move_name(id);           present(getMoveName(id)); end
    def self.move_id(sym);            s = sym.to_s.to_sym; $cache.moves[s] ? s : nil; end
    def self.move_power(id);          $cache.moves[id].basedamage; end
    def self.move_accuracy(id);       $cache.moves[id].accuracy; end
    def self.move_total_pp(id);       $cache.moves[id].maxpp; end
    def self.move_type_name(id);      type_name($cache.moves[id].type); end
    def self.move_category(id);       PokeAccess::MoveInfo::CATEGORY_SYMS[$cache.moves[id].category]; end
    def self.move_description(id);    present(getMoveDesc(id)); end
    def self.type_name(id);           present(getTypeName(id)); end
    def self.item_name(id);           present(getItemName(id)); end
    def self.species_name(id);        present(getMonName(id)); end
    def self.ability_name(id);        present(getAbilityName(id)); end
    def self.ability_description(id); present(getAbilityDesc(id)); end
    def self.nature_name(id);         present(getNatureName(id)); end

    # An item's description through the game's getItemDescription, else (Desolation has none) the item data's own,
    # which its bag and item storage paint.
    def self.item_description(id)
      present(respond_to?(:getItemDescription, true) ? getItemDescription(id) : $cache.items[id].desc)
    end

    # The plural where the game's getItemName takes plural: (Rejuvenation), else the name.
    def self.item_name_plural(id)
      plural = method(:getItemName).parameters.any? { |_kind, name| name == :plural }
      present(plural ? getItemName(id, nil, :plural => true) : getItemName(id))
    end

    # A status symbol's word, localized by the mod since neither game names its statuses in data.
    def self.status_name(st)
      k = STATUS_KEYS[st]
      k ? PokeAccess::I18n.t(k) : nil
    end

    # A PBStats number's name: the game's own full name where it has getStatName (Rejuvenation), else the mod's.
    def self.stat_name(s)
      own = respond_to?(:getStatName, true) ? present(getStatName(s, :full)) : nil
      return own if own
      k = s.is_a?(Integer) ? STAT_KEYS[s] : nil
      k ? PokeAccess::I18n.t(k) : nil
    end

    # Whether the species table is Desolation's plain Hash, one entry per species with its forms inside, rather than
    # the table of Reborn and Rejuvenation that answers [species, form].
    def self.plain_table?
      $cache.pkmn.method(:[]).arity == 1
    end

    # The species table's entry for a species' base form.
    def self.base_form(id)
      plain_table? ? $cache.pkmn[id] : $cache.pkmn[id, 0]
    end

    # The spoken names of two type symbols, the second possibly nil, each once.
    def self.type_names(first, second)
      [first, second].compact.uniq.map { |t| type_name(t) }.compact
    end

    # The pokedex entry as [name, category, dex text] from the species' base form.
    def self.species_entry(id)
      d = base_form(id)
      [species_name(id), (d.kind rescue nil), (d.dexentry rescue nil)]
    end

    # The spoken type names of a pokemon, from its symbol types (the second may be nil).
    def self.pokemon_types(pk)
      type_names(pk.type1, pk.type2)
    end

    # The spoken type names of a species' base form.
    def self.species_types(id)
      d = base_form(id)
      type_names(d.Type1, d.Type2)
    end

    # The row the Pokedex of Reborn and Desolation keeps for a species in its dexList: a Hash of :seen?, :owned? and
    # :lastSeen; nil for any other Pokedex (Rejuvenation keeps objects there, gen-6 only a flag).
    def self.dex_row(sp)
      row = (PokeAccess::Engine.player.pokedex.dexList[sp] rescue nil)
      row.is_a?(Hash) ? row : nil
    end

    # The spoken types the Pokedex entry paints for a species: those of the form last seen, from the randomizer's
    # table in a randomized game; nil without such a row. Desolation keeps a form's own types in the species'
    # formData, by form name, over the base form's.
    def self.dex_shown_types(sp)
      seen = (dex_row(sp) || {})[:lastSeen]
      return nil unless seen.is_a?(Hash)
      base = $cache.pkmn[sp]
      form = (base.forms.values.index(seen[:form]) rescue nil) || 0
      unless plain_table?
        d = ($random_dex ? ($random_dex[sp, form] rescue nil) : nil) || $cache.pkmn[sp, form]
        return type_names(d.Type1, d.Type2)
      end
      d = ($random_dex ? ($random_dex[sp] rescue nil) : nil) || base
      over = form == 0 ? nil : (base.formData[base.forms[form]] rescue nil)
      over = {} unless over.is_a?(Hash)
      type_names(over[:Type1] || d.Type1, over[:Type2] || d.Type2)
    rescue StandardError
      nil
    end

    # The stats a nature raises and lowers, as [raised, lowered] PBStats numbers (the summary colours their labels);
    # nil off the engine or for a nature that is not one of its symbols.
    def self.nature_stats(nat)
      return nil unless nat.is_a?(Symbol) && engine?
      d = ($cache.natures[nat] rescue nil)
      (d && d.respond_to?(:incStat)) ? [d.incStat, d.decStat] : nil
    end

    # A map's [region, x, y] on the town map, from the map data the engine keeps; nil off the engine or unplaced.
    def self.map_position(map_id)
      return nil unless engine?
      d = ($cache.mapdata[map_id] rescue nil)
      d ? (d.MapPosition rescue nil) : nil
    end

    # The points of a region's town map as [x, y, name, ...], where the engine keeps each region as [name, picture,
    # points] (Desolation's); nil for another shape or off the engine.
    def self.town_points(region)
      return nil unless engine?
      t = ($cache.town_map[region] rescue nil)
      (t.is_a?(Array) && t[2].is_a?(Array)) ? t[2] : nil
    end

    # The experience a Pokemon still needs for its next level, from the engine's PBExp; nil at its level cap, where
    # nothing is left, or off the engine.
    def self.exp_left(pk)
      return nil unless engine? && defined?(PBExp)
      left = PBExp.startExperience(pk.level.to_i + 1, pk.growthrate) - pk.exp.to_i
      left > 0 ? left : nil
    end

    # Whether a symbol is one of the engine's types.
    def self.type?(sym)
      engine? && !($cache.types[sym] rescue nil).nil?
    end

    # The short description the summary's skills and EV & IV pages paint under an ability, where getAbilityDesc
    # gives the full one only its ability page paints; nil off the engine.
    def self.ability_summary(id)
      return nil unless engine?
      d = ($cache.abil[id] rescue nil)
      d ? (d.desc rescue nil) : nil
    end

    # The title of a trainer class by its symbol, or nil for one the game does not have.
    def self.trainer_type_name(id)
      return nil if id.is_a?(Integer)
      t = $cache.trainertypes[id.to_s.to_sym]
      t ? present(t.title) : nil
    end

    # An item symbol parsed from an event script as [symbol, name]; the symbol is the id.
    def self.item_id(sym)
      s = sym.to_s.to_sym
      [s, ($cache.items[s] ? item_name(s) : nil)]
    end

    # The MapInfos (id => RPG::MapInfo) the engine loads into $cache at boot, from its own data folder; nil on any
    # other engine.
    def self.map_infos
      return nil unless engine? && $cache.respond_to?(:mapinfos)
      $cache.mapinfos
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Data.register(15, PokeAccess::DataRV) if PokeAccess::DataRV.engine?
