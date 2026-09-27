# games/uranium/compat.rb runs in a Ruby process of its own (it patches NilClass, Win32API and Audio for good) against
# stand-ins shaped like what mkxp-z and Uranium's scripts give it; the probe prints key=value lines to compare.
URANIUM_COMPAT_PROBE = <<'RUBY'
module Audio
  %w[bgm_fade bgm_stop bgs_fade bgs_stop me_fade me_stop se_stop].each do |m|
    (class << self; self; end).send(:define_method, m) { |*a| nil }
  end
  def self.bgm_play(name, volume = 100, pitch = 100); $played = [name, volume, pitch]; end
  def self.bgs_play(name, volume = 100, pitch = 100); $played = [name, volume, pitch]; end
  def self.me_play(name, volume = 100, pitch = 100); $played = [name, volume, pitch]; end
  def self.se_play(name, volume = 100, pitch = 100); $played = [name, volume, pitch]; end
end
class Win32API
  def initialize(dll, fn, *rest); @fn = fn; end
  def call(*args); @fn == "GetUserDefaultUILanguage" ? 0x0c0a : 7; end
end
class ProbeSystem
  attr_accessor :language
  def bgmvolume; 50; end
  def sevolume; 25; end
end
LANGUAGES = [["English", "messages.dat"], ["Espanol", "intl_spanish.dat"], ["Deutsch", "intl_german.dat"]]
def pbLoadMessages(file); $loaded = file; end
load ARGV[0]
load ARGV[0]
out = {}
out["linker_guard"] = Kernel.instance_variable_get(:@RGSS_Linker).inspect
module Audio; $fmod_guard = @bgm_play ? "set" : "nil"; $library = @library.inspect; end
out["fmod_guard"] = $fmod_guard
out["library"] = $library
out["fmodex"] = defined?(FmodEx) ? "defined" : "missing"
Audio.bgm_play("bgm", 80)
out["bgm_no_options"] = $played.inspect
$PokemonSystem = ProbeSystem.new
Audio.bgm_play("bgm", 80, 90)
out["bgm"] = $played.inspect
Audio.se_play("se")
out["se"] = $played.inspect
out["klein"] = Win32API.new("KleinBitmap.dll", "version", "", "l").call.inspect
out["rubyscreen"] = Win32API.new("./rubyscreen.dll", "TakeScreenshot", "p", "i").call("x").inspect
out["user32"] = Win32API.new("user32", "GetKeyState", "i", "i").call(1).inspect
nil.eval("def uranium_probe_section; 42; end", nil, "010:Probe")
out["section"] = uranium_probe_section.inspect
out["section_public"] = [Object.public_method_defined?(:uranium_probe_section), Kernel.uranium_probe_section].inspect
nil.eval("def uranium_probe_line; __LINE__; end", nil, "011:Line")
out["section_line"] = uranium_probe_line.inspect
nil.eval("def broken(", nil, "253:GENERATE WIKI PAGES")
nil.eval("def uranium_probe_after; 43; end", nil, "254:After")
out["skipped"] = UraniumCompat.skipped.inspect
out["after_skip"] = uranium_probe_after.inspect
nil.eval("class LanguageSelection; def main(first = false); :picker; end; end", nil, "168:Language Selection")
out["first_boot"] = LanguageSelection.new.main(true).inspect
out["language"] = $PokemonSystem.language.inspect
out["loaded"] = $loaded.inspect
out["later"] = LanguageSelection.new.main(false).inspect
module System; def self.user_language; "de_DE"; end; end
out["runtime_first"] = [LanguageSelection.new.main(true), $loaded].inspect
nil.eval("module FontInstaller; def self.install; raise 'installed'; end; end", nil, "169:PSystem_System")
out["fonts"] = FontInstaller.install.inspect
out["log"] = File.read("accessibility/compat_skipped.txt").strip.inspect
out["errors"] = File.exist?("accessibility/compat_error.txt") ? File.read("accessibility/compat_error.txt") : "none"
out.each { |k, v| puts "#{k}=#{v}" }
RUBY

Suite.define("static: el script de compatibilidad de Uranium neutraliza lo que mkxp-z no ejecuta") do
  require "rbconfig"
  require "tmpdir"
  require "fileutils"
  root = File.expand_path("../..", File.dirname(__FILE__))
  compat = File.join(root, "games", "uranium", "compat.rb")
  Dir.mktmpdir("pa_ucompat") do |dir|
    FileUtils.mkdir_p(File.join(dir, "accessibility"))
    File.open(File.join(dir, "probe.rb"), "w") { |f| f.write(URANIUM_COMPAT_PROBE) }
    text = Dir.chdir(dir) { IO.popen([RbConfig.ruby, "probe.rb", compat], :err => [:child, :out]) { |io| io.read } }
    got = {}
    text.each_line { |l| k, v = l.chomp.split("=", 2); got[k] = v if v }
    truthy "la sonda termina y responde: #{text.strip[-300, 300]}", got.key?("fonts")
    eq "RGSS Linker queda con su guarda puesta", got["linker_guard"], "{}"
    eq "FmodEx encuentra su guarda puesta", got["fmod_guard"], "set"
    eq "con una libreria que no es FmodEx", got["library"], ":mkxp"
    eq "y un FmodEx vacio", got["fmodex"], "defined"
    eq "sin opciones del juego la musica suena a su volumen", got["bgm_no_options"], '["bgm", 80, 100]'
    eq "con ellas, al volumen de musica del juego", got["bgm"], '["bgm", 40, 90]'
    eq "y los efectos al suyo", got["se"], '["se", 25, 100]'
    eq "KleinBitmap responde 0 (sin animacion de estadisticas)", got["klein"], "0"
    eq "rubyscreen tambien", got["rubyscreen"], "0"
    eq "las demas DLL no se tocan", got["user32"], "7"
    eq "una seccion que compila se evalua al nivel superior", got["section"], "42"
    eq "con sus metodos publicos, como en RGSS (Kernel.pbRgssOpen)", got["section_public"], "[true, 42]"
    eq "y sus numeros de linea de siempre", got["section_line"], "1"
    eq "la que no compila se salta y se anota", got["skipped"], '["253:GENERATE WIKI PAGES"]'
    eq "y las siguientes cargan", got["after_skip"], "43"
    truthy "el salto queda en compat_skipped.txt", got["log"].to_s.include?("253:GENERATE WIKI PAGES")
    eq "el primer arranque no abre el selector de idioma", got["first_boot"], "1"
    eq "elige el del idioma de Windows", got["language"], "1"
    eq "y carga sus mensajes", got["loaded"], '"Data/intl_spanish.dat"'
    eq "despues el selector se abre como siempre", got["later"], ":picker"
    eq "el idioma de mkxp-z manda sobre el de Windows, como en el mod", got["runtime_first"],
       '[2, "Data/intl_german.dat"]'
    eq "el instalador de fuentes no hace nada", got["fonts"], "nil"
    eq "sin errores de compatibilidad", got["errors"], "none"
  end
end
