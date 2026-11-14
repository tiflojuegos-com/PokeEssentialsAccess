# Load the complete profile in a fresh process, using a file rather than -e
# so Windows native argument transport cannot alter its Ruby source.
source = ENV.fetch('ESSENTIAL_PEA_SOURCE')
Dir.chdir(source)
require File.join(source, 'test/support/harness')
errors = Harness.load_all('xenoverse')
raise errors.inspect unless errors.empty?
expected = { 'Q' => :l, 'W' => :r, 'Z' => :a, 'X' => :b }
expected.each do |letter, button|
  raise 'Wrong native key hint: ' + letter unless PokeAccess::Config.key_hint_letters[letter] == button
end
raise 'Unverified field rules were presented as complete' if PokeAccess::FieldMoves.named?
PokeAccess::Config.language = :en
translated = PokeAccess::I18n.t(:gsel_boy)
raise 'The actual English language cache was not loaded' if translated.empty? || translated == 'gsel_boy'
puts 'PASS|xenoverse|' + ENV.fetch('PA_ENGINE') + '|0 load errors|4 actual key hints|English cache|field rules unnamed'
