# The Berrydex's dominant flavours, the ones its page circles (it paints no value, so none is said), named in the mod's
# language whether the data keys them as the plugin does ("Spicy", :spicy) or as Royal's copy does ("Picante").
# Gamedata pass, with Royal's mapping loaded.
load File.expand_path("../../../games/royal/berry_flavors.rb", File.dirname(__FILE__))

BerryFlavorsSpecData = Struct.new(:flavor)

Suite.define("berrydex: the circled flavours by name, in the mod's language, with no value") do
  t = PokeAccess::I18n
  table = {
    :PLUGINBERRY => BerryFlavorsSpecData.new({ "Spicy" => 10, "Dry" => 5, "Sweet" => 10, "Bitter" => 0, "Sour" => 0 }),
    :SYMBOLBERRY => BerryFlavorsSpecData.new({ :spicy => 0, :dry => 0, :sweet => 0, :bitter => 20, :sour => 0 }),
    :ROYALBERRY => BerryFlavorsSpecData.new({ "Picante" => 10, "Seco" => 10, "Dulce" => 0, "Amargo" => 0, "Ácido" => 0 }),
    :SOURBERRY => BerryFlavorsSpecData.new({ "Picante" => 0, "Seco" => 0, "Dulce" => 0, "Amargo" => 0, "Ácido" => 30 }),
    :BLANDBERRY => BerryFlavorsSpecData.new({ "Picante" => 0, "Seco" => 0 })
  }
  had = GameData.const_defined?(:BerryData)
  unless had
    klass = Class.new
    klass.define_singleton_method(:try_get) { |b| table[b] }
    GameData.const_set(:BerryData, klass)
  end
  begin
    bd = PokeAccess::BerryDex
    names = lambda { |*keys| t.t(:bdx_flavor, :f => keys.map { |k| t.t(k) }.join(", ")) }
    eq "the plugin's own keys", bd.flavor_line(:PLUGINBERRY), names.call(:bdx_fl_spicy, :bdx_fl_sweet)
    eq "or its symbols", bd.flavor_line(:SYMBOLBERRY), names.call(:bdx_fl_bitter)
    eq "and Royal's Spanish ones, through its profile", bd.flavor_line(:ROYALBERRY), names.call(:bdx_fl_spicy, :bdx_fl_dry)
    eq "the accented one included", bd.flavor_line(:SOURBERRY), names.call(:bdx_fl_sour)
    falsy "no value is said, as none is painted", bd.flavor_line(:ROYALBERRY).include?("10")
    eq "a berry with no flavour says none", bd.flavor_line(:BLANDBERRY), nil
    PokeAccess::Config.language = :en
    line = bd.flavor_line(:ROYALBERRY)
    truthy "in another language the words are that language's (#{line})", line.include?(t.t(:bdx_fl_spicy))
    falsy "never the data's Spanish key", line.include?("Picante")
  ensure
    PokeAccess::Config.language = :es
    GameData.send(:remove_const, :BerryData) unless had
  end
end
