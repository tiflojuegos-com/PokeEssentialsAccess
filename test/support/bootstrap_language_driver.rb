# Headless real-Ruby test: no native DLL, window or screen reader is used.
$spoken, $braille, $apis = [], [], []
$updates, $boots, $assertions = 0, 0, 0
class FakeApi
  def initialize(name); @name = name; end
  def call(*arguments)
    $apis.push([@name, arguments])
    return 0 if @name == 'PeaInitialize' && $init_fails
    if @name == 'PeaSpeak'
      if $speak_raises
        $speak_raises = false
        raise 'Owned injected bridge failure'
      end
      $spoken.push(arguments)
    end
    $braille.push(arguments) if @name == 'PeaBraille'
    1
  end
end
class Win32API
  def self.new(dll, name, inputs, output)
    raise 'Owned missing optional braille export' if name == 'PeaBraille' && $no_braille
    FakeApi.new(name)
  end
end
module Graphics
  def self.update; $updates += 1; :painted; end
end
LANGUAGES = [['Italiano', 'italian.dat'], ['English', 'english.dat']]
class Window_CommandPokemon
  attr_accessor :index, :visible, :active, :commands, :disposed
  def initialize
    @index, @visible, @active, @disposed = 0, true, true, false
    @commands = LANGUAGES.map { |row| row[0] }
  end
  def disposed?; @disposed; end
end
def pbChooseLanguage; yield; end
def equal(expected, actual)
  $assertions += 1
  raise "Expected #{expected.inspect}; got #{actual.inspect}" unless expected == actual
end
def texts; $spoken.map { |row| row[0] }; end
def frame; equal(:painted, Graphics.update); end
def ordinary_boot
  Object.send(:define_method, :pbCallTitle) { nil }
  $scene = Object.new
  frame
  equal(1, $boots)
  3.times { frame }
  equal(1, $boots)
end
load ARGV[0]
window = Window_CommandPokemon.new
case ARGV[1]
when 'selection'
  frame
  equal([], texts)
  pbChooseLanguage do
    frame; frame
    equal(["Italiano\0"], texts)
    window.index = 1; frame
    equal(["Italiano\0", "English\0"], texts)
    window.index = 0; frame
    equal(["Italiano\0", "English\0", "Italiano\0"], texts)
  end
  frame
  pbChooseLanguage { frame }
  equal(["Italiano\0", "English\0", "Italiano\0", "Italiano\0"], texts)
  equal($spoken.map { |row| [row[0]] }, $braille)
  equal([1], $spoken.map { |row| row[1] }.uniq)
  equal(false, Object.const_defined?(:PokeAccess))
  equal(0, $boots)
  ordinary_boot
  pbChooseLanguage { window.index = 1; frame }
  equal(4, texts.length)
when 'repeated_preload'
  load ARGV[0]
  pbChooseLanguage { frame; frame }
  equal(["Italiano\0"], texts)
  equal(2, $updates)
  ordinary_boot
when 'init_failure'
  $init_fails = true
  pbChooseLanguage { frame; window.index = 1; frame }
  equal([], texts)
  equal(1, $apis.select { |row| row[0] == 'PeaInitialize' }.length)
  ordinary_boot
when 'speak_failure'
  $speak_raises = true
  pbChooseLanguage { frame; frame; window.index = 1; frame }
  equal(["English\0"], texts)
  equal(1, File.read('accessibility/data/loader_error.txt').scan('early language:').length)
  ordinary_boot
when 'optional_braille'
  $no_braille = true
  pbChooseLanguage { frame }
  equal(["Italiano\0"], texts)
  equal([], $braille)
  ordinary_boot
when 'baseline'
  pbChooseLanguage { frame; window.index = 1; frame }
  equal([], texts)
  equal(0, $boots)
  ordinary_boot
else
  case ARGV[1]
  when 'invisible'; window.visible = false
  when 'inactive'; window.active = false
  when 'disposed'; window.disposed = true
  when 'wrong_commands'; window.commands = ['Unrelated', 'Screen']
  when 'negative_index'; window.index = -1
  when 'high_index'; window.index = 2
  when 'ambiguous'; other = Window_CommandPokemon.new
  else; raise 'Unknown headless case'
  end
  pbChooseLanguage { frame }
  equal([], texts)
  equal([], $apis)
  ordinary_boot
end
puts "PASS|#{ARGV[1]}|#{$assertions}|#{RUBY_VERSION}"
