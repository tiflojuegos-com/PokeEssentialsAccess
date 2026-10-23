# Boots a test process for one engine (PA_ENGINE: gen6 by default, gamedata): the engine stubs, the shared helpers,
# minitest and the base test case; then the mod with the engine's harness profile, its speech captured. With
# PA_COVERAGE set (tools/coverage.rb), the mod's line and branch coverage is written to <PA_COVERAGE>_<engine>.json.
if ENV["PA_COVERAGE"]
  require "coverage"
  require "json"
  Coverage.setup(:lines => true, :branches => true, :eval => true)
  Coverage.resume
  at_exit do
    root = File.expand_path("..", File.dirname(__FILE__)).tr("\\", "/") + "/"
    out = {}
    Coverage.result.each do |path, cov|
      rel = path.tr("\\", "/").sub(root, "")
      next unless rel =~ %r{\A(core|games|plugins|loader)/}
      branches = {}
      (cov[:branches] || {}).each { |cond, targets| targets.each { |t, n| branches["#{cond.inspect}|#{t.inspect}"] = n } }
      out[rel] = { "lines" => cov[:lines], "branches" => branches }
    end
    File.write("#{ENV['PA_COVERAGE']}_#{ENV['PA_ENGINE'] || 'gen6'}.json", JSON.generate(out))
  end
end

SUPPORT = File.expand_path("support", File.dirname(__FILE__))
require File.join(SUPPORT, "harness")
%w[speak_capture reset poke_builder world_builder tile_world hpa_helpers route_helpers guide_helpers sound_helpers
   replay game_functions arity_net].each { |f| require File.join(SUPPORT, f) }
require "minitest"
require File.join(SUPPORT, "test_case")

PROFILE = ENGINE == :gamedata ? "anil" : "pokemon_z"

load_errors = Harness.load_all(PROFILE)
unless load_errors.empty?
  puts "[#{ENGINE}] the mod failed to load:"
  load_errors.first(10).each { |e| puts "  #{e}" }
  exit 1
end
SpeakCapture.install
SpeakCapture.clear_all
