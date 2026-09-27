require "tempfile"

# The data provider of the engine Reborn and Rejuvenation share (games/rv_common/data_rv.rb): a $cache of data objects
# keyed by symbol and the game's get*Name helpers over it. The helpers below are Reborn's own, over a fake $cache.
module RVSpecCache
  Mon = Struct.new(:name, :Type1, :Type2, :kind, :dexentry)
  Move = Struct.new(:name, :type, :category, :basedamage, :accuracy, :maxpp, :desc)
  Named = Struct.new(:name, :desc)
  Ability = Struct.new(:name, :fullName, :fullDesc)
  Trainer = Struct.new(:title)

  # The species table answers [species] and [species, form], as the game's MonDataHash does.
  class Mons
    def initialize(rows); @rows = rows; end
    def [](*args); @rows.fetch(args[0]); end
    def keys; @rows.keys; end
  end

  Cache = Struct.new(:pkmn, :moves, :items, :abil, :types, :natures, :trainertypes)

  def self.build
    Cache.new(Mons.new(:PIKACHU => Mon.new("Pikachu", :ELECTRIC, nil, "Mouse", "It stores electricity."),
                       :ROTOM => Mon.new("Rotom", :ELECTRIC, :GHOST, "Plasma", "A plasma body.")),
              { :THUNDERSHOCK => Move.new("Thunder Shock", :ELECTRIC, :special, 40, 100, 30, "A jolt.") },
              { :POTION => Named.new("Potion", "Restores 20 HP.") },
              { :STATIC => Ability.new("Static", "Static", "May paralyze on contact.") },
              { :ELECTRIC => Named.new("Electric"), :GHOST => Named.new("Ghost") },
              { :TIMID => Named.new("Timid") },
              { :YOUNGSTER => Trainer.new("Youngster") })
  end
end

def getMonName(species, form = 0); $cache.pkmn[species, form].name; end
def getMoveName(move); $cache.moves[move].name; end
def getMoveDesc(move); $cache.moves[move].nil? ? "" : $cache.moves[move].desc; end
def getTypeName(type); $cache.types[type].nil? ? "" : $cache.types[type].name; end
def getItemName(item); $cache.items[item].name; end
def getItemDescription(item); $cache.items[item].desc; end
def getAbilityName(abil, short = false); $cache.abil[abil].nil? ? "" : $cache.abil[abil].fullName; end
def getAbilityDesc(abil); $cache.abil[abil].nil? ? "" : $cache.abil[abil].fullDesc; end
def getNatureName(nature); $cache.natures[nature].nil? ? "" : $cache.natures[nature].name; end

Suite.define("data: the Reborn engine's provider reads its $cache through the game's own helpers") do
  had = $cache
  $cache = RVSpecCache.build
  begin
    d = PokeAccess::DataRV
    eq "species", d.species_name(:PIKACHU), "Pikachu"
    eq "move", d.move_name(:THUNDERSHOCK), "Thunder Shock"
    eq "move power, accuracy and pp from the move data", [d.move_power(:THUNDERSHOCK), d.move_accuracy(:THUNDERSHOCK),
                                                          d.move_total_pp(:THUNDERSHOCK)], [40, 100, 30]
    eq "a move's category symbol is numbered as the other eras number it", d.move_category(:THUNDERSHOCK), 1
    eq "move type by name", d.move_type_name(:THUNDERSHOCK), "Electric"
    eq "move description", d.move_description(:THUNDERSHOCK), "A jolt."
    eq "item and its description", [d.item_name(:POTION), d.item_description(:POTION)], ["Potion", "Restores 20 HP."]
    eq "without a plural in the game, the plural is the name", d.item_name_plural(:POTION), "Potion"
    eq "ability, full name and description", [d.ability_name(:STATIC), d.ability_description(:STATIC)],
       ["Static", "May paralyze on contact."]
    eq "nature", d.nature_name(:TIMID), "Timid"
    eq "a helper's empty answer is no answer", d.type_name(:FAIRY), nil
    eq "species entry: name, category and dex text", d.species_entry(:PIKACHU), ["Pikachu", "Mouse", "It stores electricity."]
    eq "a species of one type names it once", d.species_types(:PIKACHU), ["Electric"]
    eq "and of two, both", d.species_types(:ROTOM), ["Electric", "Ghost"]
    pk = Struct.new(:type1, :type2).new(:ELECTRIC, nil)
    eq "a pokemon's symbol types, the missing second skipped", d.pokemon_types(pk), ["Electric"]
    eq "a trainer class by symbol", d.trainer_type_name(:YOUNGSTER), "Youngster"
    eq "an unknown class is nil", d.trainer_type_name("NOBODY"), nil
    eq "an item symbol from an event script is its own id", d.item_id("POTION"), [:POTION, "Potion"]
    eq "a move symbol too, when the game has it", [d.move_id("THUNDERSHOCK"), d.move_id("NOPE")], [:THUNDERSHOCK, nil]
    t = PokeAccess::I18n
    eq "its statuses are symbols, worded by the mod", [d.status_name(:SLEEP), d.status_name(:PETRIFIED)],
       [t.t(:st_sleep), t.t(:st_petrified)]
    eq "no status is no word", d.status_name(nil), nil
    eq "a stat number, worded by the mod where the game has no getStatName", [d.stat_name(1), d.stat_name(7)],
       [t.t(:st_atk), t.t(:st_evasion)]
    truthy "with this $cache the engine is recognised", d.engine?
  ensure
    $cache = had
  end
  falsy "without one it is not", PokeAccess::DataRV.engine?
end

# Desolation's shape of the same engine: a plain Hash species table, one entry per species with each form's own data
# in formData by form name, a Pokedex of species rows, natures by symbol and the town map as [name, picture, points].
module RVSpecDesolation
  Mon = Struct.new(:name, :Type1, :Type2, :forms, :formData)
  Named = Struct.new(:name)
  Nature = Struct.new(:name, :incStat, :decStat)
  MapData = Struct.new(:MapPosition)
  Cache = Struct.new(:pkmn, :moves, :abil, :types, :natures, :mapdata, :town_map)
  Dex = Struct.new(:dexList)
  Trainer = Struct.new(:pokedex)

  # A species row whose form last seen is the one named.
  def self.row(form)
    { :seen? => true, :owned? => true, :lastSeen => { :gender => "Male", :form => form, :shiny => false } }
  end
end

Suite.define("data: Desolation's species table, Pokedex rows, natures and town map through the engine's provider") do
  had = [$cache, $Trainer, $random_dex]
  d = PokeAccess::DataRV
  s = RVSpecDesolation
  begin
    alolan = { 0 => "Normal", 1 => "Alolan" }
    $cache = s::Cache.new({ :SANDSHREW => s::Mon.new("Sandshrew", :GROUND, nil, alolan, { "Alolan" => { :Type1 => :ICE, :Type2 => :STEEL } }),
                            :VULPIX => s::Mon.new("Vulpix", :FIRE, nil, alolan, { "Alolan" => { :Type1 => :ICE } }),
                            :PIKACHU => s::Mon.new("Pikachu", :ELECTRIC, nil, {}, {}) },
                          {}, {},
                          { :GROUND => s::Named.new("Ground"), :ICE => s::Named.new("Ice"), :STEEL => s::Named.new("Steel"),
                            :FIRE => s::Named.new("Fire"), :ELECTRIC => s::Named.new("Electric"), :WATER => s::Named.new("Water") },
                          { :ADAMANT => s::Nature.new("Adamant", 1, 3), :HARDY => s::Nature.new("Hardy", nil, nil) },
                          [nil, s::MapData.new([0, 7, 17])],
                          [[nil, "mapRegion0.png", [[7, 17, "Keneph Beach", "", nil, nil, nil, nil]]]])
    $Trainer = s::Trainer.new(s::Dex.new({ :SANDSHREW => s.row("Alolan"), :VULPIX => s.row("Alolan"), :PIKACHU => s.row("") }))
    $random_dex = nil
    truthy "a plain Hash is the one-entry-per-species table", d.plain_table?
    eq "whose base form is the species' own entry", d.base_form(:SANDSHREW).name, "Sandshrew"
    eq "and whose types it names", d.species_types(:SANDSHREW), ["Ground"]
    eq "the Pokedex row of a species", d.dex_row(:VULPIX)[:lastSeen][:form], "Alolan"
    eq "a form last seen shows the types its formData gives", d.dex_shown_types(:SANDSHREW), ["Ice", "Steel"]
    eq "one it gives the first of keeps the base form's second", d.dex_shown_types(:VULPIX), ["Ice"]
    eq "no form last seen shows the base form's", d.dex_shown_types(:PIKACHU), ["Electric"]
    $random_dex = { :PIKACHU => s::Mon.new("Pikachu", :WATER, nil, {}, {}) }
    eq "a randomized game shows the randomizer's types", d.dex_shown_types(:PIKACHU), ["Water"]
    $random_dex = nil
    eq "a nature's raised and lowered stats", d.nature_stats(:ADAMANT), [1, 3]
    eq "a neutral one raises nothing", d.nature_stats(:HARDY), [nil, nil]
    eq "a number is no nature of this engine", d.nature_stats(3), nil
    eq "a map's place on the town map", d.map_position(1), [0, 7, 17]
    eq "a region's town map points", d.town_points(0).first[2], "Keneph Beach"
    truthy "a type the engine has", d.type?(:ICE)
    falsy "a field icon's name that is no type", d.type?(:UP)
    $cache.town_map = [{ :filename => "map.png" }]
    eq "a town map kept another way gives no points", d.town_points(0), nil
    $cache = RVSpecCache.build
    falsy "the [species, form] table is not the plain one", d.plain_table?
    eq "and gives the base form as its form 0", d.base_form(:ROTOM).name, "Rotom"
  ensure
    $cache, $Trainer, $random_dex = had
  end
end

# Registration, in a child Ruby that loads only the data layer: the provider takes over from the fallback where the
# $cache answers, and stays out where it does not or where GameData exists.
Suite.define("data: the Reborn engine's provider registers only over such a $cache") do
  root = File.expand_path("../../..", File.dirname(__FILE__))
  script = <<-RUBY
    $VERBOSE = nil
    module PokeAccess; def self.write_marker(*); end; end
    load File.expand_path("core/data/data.rb", #{root.inspect})
    load File.expand_path("core/data/data_fallback.rb", #{root.inspect})
    bad = []
    load File.expand_path("games/rv_common/data_rv.rb", #{root.inspect})
    bad << "registered with no $cache" unless PokeAccess::Data.active == PokeAccess::DataFallback
    $cache = Struct.new(:pkmn, :moves, :abil).new({}, {}, {})
    load File.expand_path("games/rv_common/data_rv.rb", #{root.inspect})
    bad << "not registered over the $cache" unless PokeAccess::Data.active == PokeAccess::DataRV
    bad << "priority" unless PokeAccess::Data.active_priority == 15
    module GameData; end
    bad << "engine? with GameData" if PokeAccess::DataRV.engine?
    print(bad.empty? ? "OK" : "FAIL: " + bad.join(", "))
  RUBY
  file = Tempfile.new(["pa_rv", ".rb"])
  begin
    file.write(script); file.close
    out = `ruby "#{file.path}" 2>&1`
  ensure
    file.unlink
  end
  eq "isolated load reports OK", out.strip, "OK"
end
