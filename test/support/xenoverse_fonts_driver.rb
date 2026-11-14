# Headless native-API contract, executed under both actual Ruby interpreters.
$calls = []
require 'stringio'
fallback = ['log-failure', 'core-log-failure'].include?(ARGV[1])
if fallback
  $stderr = StringIO.new
  class << File
    alias xenoverse_original_open open
    def open(path, *args, &block)
      raise IOError, 'Owned unavailable font log' if path == 'accessibility/data/compat_fonts.txt'
      xenoverse_original_open(path, *args, &block)
    end
  end
end
if ARGV[1] == 'core-log-failure'
  module PokeAccess
    def self.write_marker(message); ($core_markers ||= []).push(message); end
  end
end
class Win32API
  def self.new(dll, name, inputs, output)
    raise 'Unexpected native API' unless dll == 'gdi32' && name == 'AddFontResourceExA' && inputs == ['p', 'i', 'i'] && output == 'i'
    raise 'Owned unavailable font API' if ['failure', 'log-failure', 'core-log-failure'].include?(ARGV[1])
    self.allocate
  end
  def call(*args); $calls.push(args); ARGV[1] == 'refused' ? 0 : 1; end
end
def check(condition, message)
  $assertions = ($assertions || 0) + 1
  raise message unless condition
end
load ARGV[0]
if fallback
  messages = ARGV[1] == 'core-log-failure' ? ($core_markers || []).join('\n') : $stderr.string
  check(messages.include?('Owned unavailable font API'), 'The original font failure must reach the fallback')
  check(messages.include?('font log unavailable: IOError: Owned unavailable font log'), 'The failed log channel must stay diagnosable')
  check(XenoverseCompat.registered_fonts == 0, 'A failed API must not count as registration')
  check(!!defined?(PokeAccess) == (ARGV[1] == 'core-log-failure'), 'The bootstrap must not create PokeAccess early')
elsif ARGV[1] == 'failure'
  check(File.read('accessibility/data/compat_fonts.txt').include?('Owned unavailable font API'), 'A font API failure must stay diagnosable')
  check(XenoverseCompat.registered_fonts == 0, 'A failed API must not count as registration')
else
  check($calls.length == 2, 'Only TTF/OTF files should be registered')
  check($calls.all? { |row| row[0][-1, 1] == "\0" && row[1, 2] == [16, 0] }, 'Font registration must be process private')
  if ARGV[1] == 'refused'
    check(XenoverseCompat.registered_fonts == 0, 'Refused registrations must not count as success')
    check(File.read('accessibility/data/compat_fonts.txt').scan('Private font registration failed:').length == 2, 'Each refusal must stay diagnosable')
  else
    check(XenoverseCompat.registered_fonts == 2, 'Actual registration count differs')
  end
end
module FontInstaller
  def self.install; raise 'Forbidden system installation/restart'; end
  def self.keep; :original_other_method; end
end
check(FontInstaller.install.nil?, 'The later original installer definition must stay inactive')
check(FontInstaller.keep == :original_other_method, 'Unrelated methods must be preserved')
module FontInstaller
  def self.install; raise 'Forbidden reset installation/restart'; end
end
check(FontInstaller.install.nil?, 'A game reset must not restore the old installer')
puts "PASS|#{ARGV[1]}|#{$assertions}|#{RUBY_VERSION}"
