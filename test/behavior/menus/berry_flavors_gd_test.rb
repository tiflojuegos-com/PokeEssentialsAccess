# The Berrydex's dominant flavours, the ones its page circles (it paints no value, so none is said), named in the mod's
# language whether the data keys them as the plugin does ("Spicy", :spicy) or as Royal's copy does ("Picante").
class BerryFlavorsGdTest < PokeAccessTest
  # Royal's mapping, loaded once from its profile and kept apart (with_royal puts it in); the core's flavor_key stays in
  # place for the other tests of the process.
  META = (class << PokeAccess::BerryDex; self; end)
  CORE = META.instance_method(:flavor_key)
  PATH = File.join(Harness::ROOT, "games", "royal", "berry_flavors.rb")
  eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ROYAL = META.instance_method(:flavor_key)
  META.send(:define_method, :flavor_key, CORE)

  # A berry as GameData::BerryData keeps it: its flavour table.
  Berry = Struct.new(:flavor)

  test "names every flavour at the top, as the plugin's data keys them" do
    with_berries(:B => { "Spicy" => 10, "Dry" => 5, "Sweet" => 10, "Bitter" => 0, "Sour" => 0 }) do
      assert_equal dominant(:bdx_fl_spicy, :bdx_fl_sweet), PokeAccess::BerryDex.flavor_line(:B)
    end
  end

  test "names a flavour the data keys by symbol" do
    with_berries(:B => { :spicy => 0, :dry => 0, :sweet => 0, :bitter => 20, :sour => 0 }) do
      assert_equal dominant(:bdx_fl_bitter), PokeAccess::BerryDex.flavor_line(:B)
    end
  end

  test "names Royal's Spanish keys through its profile" do
    table = { "Picante" => :bdx_fl_spicy, "Seco" => :bdx_fl_dry, "Dulce" => :bdx_fl_sweet,
              "Amargo" => :bdx_fl_bitter, "Ácido" => :bdx_fl_sour }
    with_royal do
      table.each do |key, word|
        with_berries(:B => { "Picante" => 0, key => 30 }) do
          assert_equal dominant(word), PokeAccess::BerryDex.flavor_line(:B), "for #{key}"
        end
      end
    end
  end

  test "Royal's mapping passes on a key it does not know" do
    with_royal do
      with_berries(:B => { "Spicy" => 10, :dry => 10 }) do
        assert_equal dominant(:bdx_fl_spicy, :bdx_fl_dry), PokeAccess::BerryDex.flavor_line(:B)
      end
    end
  end

  test "says a flavour no table knows by the data's own key" do
    with_berries(:B => { "Picante" => 10, "Seco" => 0 }) do
      assert_equal PokeAccess::I18n.t(:bdx_flavor, :f => "Picante"), PokeAccess::BerryDex.flavor_line(:B)
    end
  end

  test "names the flavours in the mod's language, never by the data's Spanish keys" do
    PokeAccess::Config.language = :en
    with_berries(:B => { "Picante" => 10, "Seco" => 10 }) do
      with_royal do
        assert_equal dominant(:bdx_fl_spicy, :bdx_fl_dry), PokeAccess::BerryDex.flavor_line(:B)
      end
    end
  end

  test "says no flavour for a berry without one above zero or without a flavour table it can read" do
    berries = { :ZERO => { "Picante" => 0, "Seco" => 0 }, :EMPTY => {}, :NOFLAVOR => nil, :LISTED => [10, 0, 0, 0, 0],
                :UNREADABLE => { "Picante" => Object.new } }
    with_berries(berries) do
      (berries.keys + [:UNKNOWN]).each { |b| assert_nil PokeAccess::BerryDex.flavor_line(b), "for #{b}" }
    end
  end

  private

  # The line naming the given flavour words, as the page's reader says it, in the language set now.
  def dominant(*keys)
    PokeAccess::I18n.t(:bdx_flavor, :f => keys.map { |k| PokeAccess::I18n.t(k) }.join(", "))
  end

  # Runs the block with GameData::BerryData answering try_get from table (berry => its flavours; a berry left out has
  # no data), whatever stood under the name put back after.
  def with_berries(table)
    held = GameData.const_defined?(:BerryData, false) ? GameData::BerryData : nil
    GameData.send(:remove_const, :BerryData) if held
    data = Class.new
    data.define_singleton_method(:try_get) { |b| table.key?(b) ? Berry.new(table[b]) : nil }
    GameData.const_set(:BerryData, data)
    yield
  ensure
    GameData.send(:remove_const, :BerryData) if GameData.const_defined?(:BerryData, false)
    GameData.const_set(:BerryData, held) if held
  end

  # Runs the block with Royal's flavour mapping in place of the core's.
  def with_royal
    META.send(:define_method, :flavor_key, ROYAL)
    yield
  ensure
    META.send(:define_method, :flavor_key, CORE)
  end
end
