module PokeAccess
  # GameData data provider (v19+), registered above gen-6 so an engine that also ships PB* shims resolves through
  # GameData. Resolvers stay raw: PokeAccess::Data.resolve rescues every call.
  module DataV21
    def self.move_name(id);        GameData::Move.get(id).name; end
    # A move symbol is its own id; nil for one the game does not have.
    def self.move_id(sym);         GameData::Move.exists?(sym) ? sym : nil; end
    # power, or base_damage (its name before v21), which both Infinite Fusion games keep.
    def self.move_power(id);       PokeAccess.attr_of(GameData::Move.get(id), :power, :base_damage); end
    def self.move_accuracy(id);    GameData::Move.get(id).accuracy; end
    def self.move_total_pp(id);    PokeAccess.attr_of(GameData::Move.get(id), :total_pp, :totalpp); end
    def self.move_type_name(id);   GameData::Type.get(GameData::Move.get(id).type).name; end
    def self.move_category(id);    GameData::Move.get(id).category; end
    def self.move_description(id); GameData::Move.get(id).description; end
    def self.type_name(id);        GameData::Type.get(id).name; end
    def self.item_name(id);        GameData::Item.get(id).name; end
    # name_plural first, for the Infinite Fusion games: they keep that v19 accessor and lack the portion_* pair.
    def self.item_name_plural(id); d = GameData::Item.get(id); (d.name_plural rescue nil) || (d.portion_name_plural rescue nil) || (d.portion_name rescue nil) || d.name; end
    def self.item_description(id); GameData::Item.get(id).description; end
    def self.species_name(id);     GameData::Species.get(id).name; end
    def self.ability_name(id);     GameData::Ability.get(id).name; end
    def self.ability_description(id); GameData::Ability.get(id).description; end
    def self.nature_name(id);      GameData::Nature.get(id).name; end
    def self.status_name(st);      GameData::Status.get(st).name; end
    def self.stat_name(s);         GameData::Stat.get(s).name; end

    # The species pokedex entry as [name, category, dex_text] from the GameData::Species registry.
    def self.species_entry(id)
      d = GameData::Species.get(id)
      [d.name, (d.category rescue nil), (d.pokedex_entry rescue nil)]
    end

    # A Pokemon's form name as GameData gives it: its species form's form_name, which can name the first form too; nil
    # for a form with no name.
    def self.form_name(pk)
      name = pk.species_data.form_name.to_s.strip
      name.empty? ? nil : name
    end

    # The spoken type names of a pokemon, from its modern symbol types.
    def self.pokemon_types(pk)
      (pk.types rescue []).map { |s| (GameData::Type.get(s).name rescue nil) }.compact
    end

    # The spoken type names of a species: types from v20, the type1/type2 pair v19 still had.
    def self.species_types(id)
      d = GameData::Species.get(id)
      ts = d.respond_to?(:types) ? d.types : [d.type1, d.type2]
      ts.compact.uniq.map { |s| (GameData::Type.get(s).name rescue nil) }.compact
    end

    # National numbers that name one species each, by its constant: every tenth and the last of each release, where a
    # game's species list tends to end. national_order checks the game's own order against them.
    NATIONAL_ANCHORS = {
      1 => :BULBASAUR, 10 => :CATERPIE, 20 => :RATICATE, 30 => :NIDORINA, 40 => :WIGGLYTUFF, 50 => :DIGLETT,
      60 => :POLIWAG, 70 => :WEEPINBELL, 80 => :SLOWBRO, 90 => :SHELLDER, 100 => :VOLTORB, 110 => :WEEZING,
      120 => :STARYU, 130 => :GYARADOS, 140 => :KABUTO, 150 => :MEWTWO, 151 => :MEW, 160 => :FERALIGATR,
      170 => :CHINCHOU, 180 => :FLAAFFY, 190 => :AIPOM, 200 => :MISDREAVUS, 210 => :GRANBULL, 220 => :SWINUB,
      230 => :KINGDRA, 240 => :MAGBY, 250 => :HOOH, 251 => :CELEBI, 260 => :SWAMPERT, 270 => :LOTAD, 280 => :RALTS,
      290 => :NINCADA, 300 => :SKITTY, 310 => :MANECTRIC, 320 => :WAILMER, 330 => :FLYGON, 340 => :WHISCASH,
      350 => :MILOTIC, 360 => :WYNAUT, 370 => :LUVDISC, 380 => :LATIAS, 386 => :DEOXYS, 390 => :CHIMCHAR,
      400 => :BIBAREL, 410 => :SHIELDON, 420 => :CHERUBI, 430 => :HONCHKROW, 440 => :HAPPINY, 450 => :HIPPOWDON,
      460 => :ABOMASNOW, 470 => :LEAFEON, 480 => :UXIE, 490 => :MANAPHY, 493 => :ARCEUS, 500 => :EMBOAR,
      510 => :LIEPARD, 520 => :TRANQUILL, 530 => :EXCADRILL, 540 => :SEWADDLE, 550 => :BASCULIN, 560 => :SCRAFTY,
      570 => :ZORUA, 580 => :DUCKLETT, 590 => :FOONGUS, 600 => :KLANG, 610 => :AXEW, 620 => :MIENSHAO,
      630 => :MANDIBUZZ, 640 => :VIRIZION, 649 => :GENESECT, 650 => :CHESPIN, 660 => :DIGGERSBY, 670 => :FLOETTE,
      680 => :DOUBLADE, 690 => :SKRELP, 700 => :SYLVEON, 710 => :PUMPKABOO, 720 => :HOOPA, 721 => :VOLCANION,
      730 => :PRIMARINA, 740 => :CRABOMINABLE, 750 => :MUDSDALE, 760 => :BEWEAR, 770 => :PALOSSAND, 780 => :DRAMPA,
      790 => :COSMOEM, 800 => :NECROZMA, 802 => :MARSHADOW, 807 => :ZERAORA, 809 => :MELMETAL, 810 => :GROOKEY,
      820 => :GREEDENT, 830 => :ELDEGOSS, 840 => :APPLIN, 850 => :SIZZLIPEDE, 860 => :MORGREM, 870 => :FALINKS,
      880 => :DRACOZOLT, 890 => :ETERNATUS, 893 => :ZARUDE, 898 => :CALYREX, 900 => :KLEAVOR, 905 => :ENAMORUS,
      910 => :CROCALOR, 920 => :LOKIX, 930 => :ARBOLIVA, 940 => :WATTREL, 950 => :KLAWF, 960 => :WIGLETT,
      970 => :GLIMMORA, 980 => :CLODSIRE, 990 => :IRONTREADS, 1000 => :GHOLDENGO, 1010 => :IRONLEAVES,
      1017 => :OGERPON, 1020 => :GOUGINGFIRE, 1024 => :TERAPAGOS, 1025 => :PECHARUNT
    }

    # The species a national number names (an overworld sprite's "025"), or nil: the number itself where species are
    # keyed by number (v19, Infinite Fusion), else that place in national_order.
    def self.national_species(n)
      return n if GameData::Species::DATA.key?(n)
      order = national_order
      n >= 1 && n <= order.length ? order[n - 1] : nil
    end

    # The first forms in the order the game loads them, the one its Pokedex numbers, cut at national_limit: empty
    # when that order does not begin as the national one or the species are not loaded yet. Kept until the species
    # table is replaced.
    def self.national_order
      data = GameData::Species::DATA
      return [] if data.empty?
      return @national_order if @national_data.equal?(data)
      order = []
      GameData::Species.each_species { |s| order.push(s.id) } if GameData::Species.respond_to?(:each_species)
      @national_data = data
      @national_order = order[0, national_limit(order)]
    end

    # How far order follows the national one: up to the last anchor it matches before the first it misses, among those
    # its length reaches; 0 when it misses the first.
    def self.national_limit(order)
      limit = 0
      NATIONAL_ANCHORS.keys.sort.each do |n|
        break if n > order.length || order[n - 1] != NATIONAL_ANCHORS[n]
        limit = n
      end
      limit
    end

    # The name of a trainer class by its id, or nil, never asking the table about an id it does not know (see
    # safe_item_name): the ids come from sprite file names, which name classes a game may not have.
    def self.trainer_type_name(id)
      key = id.is_a?(Integer) ? id : id.to_s.to_sym
      tt = GameData::TrainerType
      return (tt.try_get(key).name rescue nil) if tt.respond_to?(:try_get)
      return nil if tt.respond_to?(:exists?) && !tt.exists?(key)
      tt.get(key).name
    end

    # An item symbol or name parsed from an event script as [symbol, name]; modern items are keyed by symbol.
    def self.item_id(sym)
      s = sym.to_s.to_sym
      [s, (safe_item_name(s) rescue nil)]
    end

    # An item's name, or nil, never asking the table about an id it does not know: try_get, then exists?, because
    # get on an unknown id can recurse into SystemStackError (Infinite Fusion), which rescue does not catch.
    def self.safe_item_name(s)
      return (GameData::Item.try_get(s).name rescue nil) if GameData::Item.respond_to?(:try_get)
      return nil if GameData::Item.respond_to?(:exists?) && !GameData::Item.exists?(s)
      GameData::Item.get(s).name
    end
  end
end

PokeAccess::Data.register(20, PokeAccess::DataV21) if defined?(GameData) && defined?(GameData::Move)
