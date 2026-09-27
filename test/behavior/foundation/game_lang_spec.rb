# GameLang: the build's language from the game's own LANGUAGES table, read live at $PokemonSystem.language; an
# entry counts only when the message file it names ships (otherwise it is template residue).
Suite.define("game_lang: the build's own declaration decides, and only with its file on disk") do
  eq "with no LANGUAGES table there is no declared language", PokeAccess::GameLang.code, nil
  eq "and pick() then falls back to the authored base",
     PokeAccess::GameLang.pick({ :es => "hola", :en => "hello" }, :es), "hola"
  eq "a plain value passes through untouched", PokeAccess::GameLang.pick("suelto", :es), "suelto"

  dir = File.join(File.dirname(__FILE__), "tmp_gamelang")
  data = File.join(dir, "Data")
  require "fileutils"
  FileUtils.mkdir_p(data)
  ps = Object.new
  class << ps; attr_accessor :language; end
  old_ps = $PokemonSystem
  begin
    File.open(File.join(data, "english.dat"), "wb") { |f| f.write("x") }
    Object.const_set(:LANGUAGES, [["English", "english.dat"], ["Espanol", "spanish.dat"]])
    $PokemonSystem = ps
    Dir.chdir(dir) do
      ps.language = 0
      eq "an entry whose file ships is believed", PokeAccess::GameLang.code, :en
      eq "and pick() serves that build's transcription",
         PokeAccess::GameLang.pick({ :es => "hola", :en => "hello" }, :es), "hello"

      ps.language = 1
      eq "an entry whose file does NOT ship is template residue, not a language",
         PokeAccess::GameLang.code, nil

      Object.send(:remove_const, :LANGUAGES)
      Object.const_set(:LANGUAGES, [[[0x46, 0x72, 0x61, 0x6E, 0xC3, 0xA7, 0x61, 0x69, 0x73].pack("C*"), "english.dat"]])
      ps.language = 0
      eq "an accented native name folds to its code", PokeAccess::GameLang.code, :fr

      Object.send(:remove_const, :LANGUAGES)
      Object.const_set(:LANGUAGES, [])
      eq "an empty table (the commented-out template) declares nothing", PokeAccess::GameLang.code, nil
    end
  ensure
    Object.send(:remove_const, :LANGUAGES) if Object.const_defined?(:LANGUAGES)
    $PokemonSystem = old_ps
    FileUtils.rm_rf(dir)
  end
end
