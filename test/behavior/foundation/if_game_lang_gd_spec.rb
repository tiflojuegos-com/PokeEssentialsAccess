# Infinite Fusion's per-game LANGUAGES, a Hash keyed by Settings::GAME_ID: the language the game runs in comes from
# the running game's own list, where Hoenn declares French and Chinese.
Suite.define("if game language: the running game's list in the per-game table decides") do
  gl = PokeAccess::GameLang
  plain = gl.method(:languages_table)
  overrides = PokeAccess::Hooks.overrides.length
  dir = File.join(File.dirname(__FILE__), "tmp_if_gamelang")
  require "fileutils"
  FileUtils.mkdir_p(File.join(dir, "Data"))
  ps = Object.new
  class << ps; attr_accessor :language; end
  old_ps = $PokemonSystem
  begin
    load File.join(Harness::ROOT, "games", "infinitefusion_common", "game_lang.rb")
    File.open(File.join(dir, "Data", "french.dat"), "wb") { |f| f.write("x") }
    ::Settings.const_set(:GAME_ID, :IF_HOENN)
    ::Settings.const_set(:LANGUAGES, { :IF_KANTO => [["English", "english.dat"]],
                                       :IF_HOENN => [["English", "english.dat"], ["Français", "french.dat"]] })
    $PokemonSystem = ps
    Dir.chdir(dir) do
      ps.language = 1
      eq "Hoenn's second entry, whose file ships, is French", gl.code, :fr
      ps.language = 0
      eq "its English entry names no file the game ships, so nothing is declared", gl.code, nil
    end
  ensure
    [:LANGUAGES, :GAME_ID].each { |c| ::Settings.send(:remove_const, c) if ::Settings.const_defined?(c) }
    gl.define_singleton_method(:languages_table, plain)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
    $PokemonSystem = old_ps
    FileUtils.rm_rf(dir)
  end
end
