# Infinite Fusion keeps one LANGUAGES list per game in a Hash keyed by Settings::GAME_ID (Hoenn's declares French):
# the language the game runs in comes from the running game's own list (games/infinitefusion_common/game_lang.rb).
class IfGameLangGdTest < PokeAccessTest
  Options = Struct.new(:language)
  PROFILE = File.join(Harness::ROOT, "games", "infinitefusion_common", "game_lang.rb")
  PER_GAME = { :IF_KANTO => [["English", "english.dat"]],
               :IF_HOENN => [["English", "english.dat"], ["Français", "french.dat"]] }.freeze
  SHIPPED = %w[english.dat french.dat].freeze

  test "reads the language from the running game's own list" do
    { :IF_HOENN => :fr, :IF_KANTO => :en }.each do |game, want|
      in_if_build(PER_GAME, game, 1) { assert_equal want, PokeAccess::GameLang.code, "for #{game}" }
    end
  end

  test "declares nothing for a game the table holds no list for" do
    [:IF_JOHTO, nil].each do |game|
      in_if_build(PER_GAME, game, 0) { assert_nil PokeAccess::GameLang.code, "for #{game.inspect}" }
    end
  end

  test "takes an entry of the running game's list whose file does not ship for template residue" do
    in_if_build(PER_GAME, :IF_HOENN, 0, %w[french.dat]) { assert_nil PokeAccess::GameLang.code }
  end

  test "reads a LANGUAGES that is one list for every game as core does" do
    in_if_build([["Français", "french.dat"]], :IF_HOENN, 0) { assert_equal :fr, PokeAccess::GameLang.code }
  end

  private

  # Runs the block with the Infinite Fusion profile's reading of LANGUAGES installed, in a scratch game folder whose
  # Data/ ships shipped, with Settings::LANGUAGES set to table, Settings::GAME_ID to game (none for nil) and the game's
  # options at language index; all put back afterwards.
  def in_if_build(table, game, index, shipped = SHIPPED)
    gl = PokeAccess::Game
    lang = PokeAccess::GameLang
    plain = lang.method(:languages_table)
    overrides = PokeAccess::Hooks.overrides.length
    profiles = gl.profiles.dup
    profile_name = gl.instance_variable_get(:@profile_name)
    was = $PokemonSystem
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "Data"))
      shipped.each { |f| File.open(File.join(dir, "Data", f), "wb") { |io| io.write("x") } }
      begin
        eval(Harness.source(PROFILE), TOPLEVEL_BINDING, PROFILE)
        ::Settings.const_set(:LANGUAGES, table)
        ::Settings.const_set(:GAME_ID, game) unless game.nil?
        $PokemonSystem = Options.new(index)
        Dir.chdir(dir) { yield }
      ensure
        $PokemonSystem = was
        [:LANGUAGES, :GAME_ID].each { |c| ::Settings.send(:remove_const, c) if ::Settings.const_defined?(c, false) }
        lang.define_singleton_method(:languages_table, plain)
        PokeAccess::Hooks.overrides.slice!(overrides..-1)
        gl.instance_variable_set(:@profiles, profiles)
        gl.instance_variable_set(:@profile_name, profile_name)
      end
    end
  end
end
