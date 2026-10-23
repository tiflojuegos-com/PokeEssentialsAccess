require "rbconfig"
require "tmpdir"

# The data layer (core/data/data.rb) over its fallback, which serves at priority 0 naming things by their raw ids until
# an engine's provider joins on its own engine; the highest priority serves, and a provider's exception is no datum.
class ProviderFallbackTest < PokeAccessTest
  LAYER = PokeAccess::Data
  FALLBACK = PokeAccess::DataFallback
  LAYER_FILES = %w[core/data/data.rb core/data/data_fallback.rb].freeze
  LAYER_STATE = [:@providers, :@active_entry, :@errors].freeze
  FALLBACK_SERVES = ["PokeAccess::DataFallback", 0].freeze

  # The fallback's answer to each resolver it can answer: every name is the raw id (a species entry has only its name),
  # every id the id itself, and the type lists are empty.
  RAW = {
    [:move_name, :TACKLE] => "TACKLE", [:type_name, :FIRE] => "FIRE", [:item_name, :POTION] => "POTION",
    [:item_name_plural, :POTION] => "POTION", [:species_name, 25] => "25", [:ability_name, :STATIC] => "STATIC",
    [:nature_name, :BOLD] => "BOLD", [:stat_name, :ATTACK] => "ATTACK", [:species_entry, :PIKACHU] => ["PIKACHU", nil, nil],
    [:item_id, :POTION] => [:POTION, "POTION"], [:move_id, :TACKLE] => :TACKLE, [:pokemon_types, nil] => [],
    [:species_types, :PIKACHU] => []
  }.freeze

  # The resolvers whose datum only an engine knows.
  UNKNOWN = [:move_power, :move_accuracy, :move_total_pp, :move_type_name, :move_category, :move_description,
             :item_description, :ability_description, :status_name, :trainer_type_name].freeze

  test "serves alone, at priority 0, once the layer boots with no engine's provider" do
    assert_equal FALLBACK_SERVES, in_fresh_ruby("serving")
  end

  test "gives way to gen-6's provider, at priority 10, only where the PB* tables are and GameData is not" do
    probe = <<-'PROBE'
      none = serving("core/data/gen6/data_g6.rb")
      Object.const_set(:PBMoves, Module.new)
      tables = serving("core/data/gen6/data_g6.rb")
      Object.const_set(:GameData, Module.new)
      [none, tables, serving("core/data/gen6/data_g6.rb")]
    PROBE
    assert_equal [FALLBACK_SERVES, ["PokeAccess::DataG6", 10], FALLBACK_SERVES],
                 in_fresh_ruby(probe, ["core/data/gen6/data_g6.rb"]), "with no tables, with PBMoves, with GameData beside it"
  end

  test "gives way to GameData's provider, at priority 20, only where GameData has its Move registry" do
    probe = <<-'PROBE'
      none = serving("core/data/v21/data_v21.rb")
      Object.const_set(:GameData, Module.new)
      bare = serving("core/data/v21/data_v21.rb")
      GameData.const_set(:Move, Module.new)
      [none, bare, serving("core/data/v21/data_v21.rb")]
    PROBE
    assert_equal [FALLBACK_SERVES, FALLBACK_SERVES, ["PokeAccess::DataV21", 20]],
                 in_fresh_ruby(probe, ["core/data/v21/data_v21.rb"]), "with no GameData, with one lacking Move, with Move"
  end

  test "gives way to the Reborn engine's provider, at priority 15, only over its $cache and never beside GameData" do
    probe = <<-'PROBE'
      none = serving("games/rv_common/data_rv.rb")
      $cache = Struct.new(:pkmn, :moves, :abil).new({}, {}, {})
      over = serving("games/rv_common/data_rv.rb")
      Object.const_set(:GameData, Module.new)
      [none, over, serving("games/rv_common/data_rv.rb")]
    PROBE
    assert_equal [FALLBACK_SERVES, ["PokeAccess::DataRV", 15], FALLBACK_SERVES],
                 in_fresh_ruby(probe, ["games/rv_common/data_rv.rb"]), "with no $cache, over its $cache, beside GameData"
  end

  test "names a thing by its raw id and leaves empty every datum only an engine knows" do
    with_layer([0, FALLBACK]) do |marks|
      RAW.each { |(method, arg), want| assert_equal want, LAYER.send(method, arg), "#{method}(#{arg.inspect})" }
      UNKNOWN.each { |method| assert_nil LAYER.send(method, :TACKLE), method.to_s }
      assert_equal [[], []], [LAYER.errors, marks], "every answer given without an error noted or written"
    end
  end

  test "the highest priority registered serves, whichever registered first" do
    high = provider("high")
    with_layer([0, FALLBACK]) do
      assert_equal "TACKLE", LAYER.move_name(:TACKLE), "the fallback alone"
      LAYER.register(20, high)
      assert_equal [high, 20, "high TACKLE"], [LAYER.active, LAYER.active_priority, LAYER.move_name(:TACKLE)],
                   "a higher one joining takes over"
      LAYER.register(10, provider("low"))
      assert_equal [high, 20, "high TACKLE"], [LAYER.active, LAYER.active_priority, LAYER.move_name(:TACKLE)],
                   "a lower one joining later does not"
    end
  end

  test "with no provider at all, every datum is nil and the type lists empty, and no error is noted" do
    with_layer do |marks|
      assert_equal [nil, nil], [LAYER.active, LAYER.active_priority], "nothing serves"
      assert_nil LAYER.move_name(:TACKLE), "a name"
      assert_equal [[], []], [LAYER.pokemon_types(nil), LAYER.species_types(:PIKACHU)], "the type lists"
      assert_nil LAYER.optional(:dex_row, :PIKACHU), "an optional datum"
      assert_equal [[], []], [LAYER.errors, marks], "the errors and the marker"
    end
  end

  test "a provider's exception is no datum, noted once per method and class and written to the marker" do
    broken = Module.new do
      def self.move_name(id); raise ArgumentError, "no move #{id}"; end
      def self.item_name(id); id == :KEY ? raise(TypeError, "a key item") : raise(ArgumentError, "no item #{id}"); end
    end
    with_layer([0, FALLBACK], [30, broken]) do |marks|
      assert_equal [nil, nil, nil, nil],
                   [LAYER.move_name(:A), LAYER.move_name(:B), LAYER.item_name(:POTION), LAYER.item_name(:KEY)], "no datum"
      noted = ["move_name: ArgumentError: no move A", "item_name: ArgumentError: no item POTION",
               "item_name: TypeError: a key item"]
      assert_equal noted, LAYER.errors, "each method and exception class once, with its first message"
      assert_equal noted.map { |e| "data provider error -- #{e}\n" }, marks, "each written to the marker once"
    end
  end

  test "an error is still noted when the marker cannot be written" do
    broken = Module.new { def self.move_name(_id); raise ArgumentError, "no move"; end }
    with_layer([30, broken], :marker => lambda { |*| raise IOError, "the disk is full" }) do
      assert_nil LAYER.move_name(:A), "no datum"
      assert_equal ["move_name: ArgumentError: no move"], LAYER.errors, "the error noted"
    end
  end

  test "an optional datum is asked with all its arguments, and is nil where the provider lacks it or raises" do
    extra = Module.new do
      def self.town_points(region, kind); [region, kind]; end
      def self.map_infos; raise IOError, "no MapInfos"; end
    end
    with_layer([0, FALLBACK], [30, extra]) do
      assert_equal [2, :nests], LAYER.optional(:town_points, 2, :nests), "answered with every argument"
      assert_nil LAYER.optional(:dex_row, :PIKACHU), "a datum the provider does not give"
      assert_nil LAYER.optional(:map_infos), "one it raises on"
      assert_equal ["map_infos: IOError: no MapInfos"], LAYER.errors, "only the exception noted"
    end
  end

  private

  # Runs the block on a data layer of its own holding only entries ([priority, provider]), no error noted yet and
  # write_marker keeping its lines in the array the block gets (or doing what marker does); all is put back after.
  def with_layer(*entries, marker: nil)
    saved = LAYER_STATE.map { |v| LAYER.instance_variable_get(v) }
    writer = PokeAccess.method(:write_marker)
    marks = []
    LAYER_STATE.zip([[], nil, nil]).each { |v, value| LAYER.instance_variable_set(v, value) }
    PokeAccess.define_singleton_method(:write_marker, &(marker || lambda { |text = ""| marks << text }))
    entries.each { |priority, provider| LAYER.register(priority, provider) }
    yield marks
  ensure
    LAYER_STATE.zip(saved).each { |v, value| LAYER.instance_variable_set(v, value) }
    PokeAccess.define_singleton_method(:write_marker, writer)
  end

  # A provider naming every move "<tag> <id>".
  def provider(tag)
    Module.new { define_singleton_method(:move_name) { |id| "#{tag} #{id}" } }
  end

  # The value probe (Ruby source) returns in a child Ruby where serving(*files) boots the layer afresh with those files
  # of the mod, evaluated as the harness evaluates them (a mutant included), and answers who serves as [provider's
  # name, priority].
  def in_fresh_ruby(probe, files = [])
    sources = Hash[(LAYER_FILES + files).map { |rel| [rel, Harness.source(File.join(Harness::ROOT, rel))] }]
    Dir.mktmpdir("pa_data_layer") do |dir|
      out = File.join(dir, "result")
      script = File.join(dir, "probe.rb")
      File.write(script, "$VERBOSE = nil\nmodule PokeAccess; def self.write_marker(*); end; end\n" \
                         "SOURCES = #{sources.inspect}\nLAYER = #{LAYER_FILES.inspect}\n" \
                         "def serving(*files)\n" \
                         "  (LAYER + files).each { |rel| eval(SOURCES.fetch(rel), TOPLEVEL_BINDING, rel) }\n" \
                         "  [PokeAccess::Data.active.name, PokeAccess::Data.active_priority]\n" \
                         "end\n" \
                         "File.binwrite(#{out.inspect}, Marshal.dump(begin\n#{probe}\nend))\n")
      log = IO.popen([RbConfig.ruby, "--disable-gems", script, :err => [:child, :out]], &:read)
      flunk "the child Ruby failed: #{log}" unless File.file?(out)
      Marshal.load(File.binread(out))
    end
  end
end
