require "rbconfig"
require "tempfile"

# The tests of a profile loaded whole in a process of its own, over a world of classes shaped as the game's: its
# overrides would reach every other test here, and what it declares has to bind. The play runs after the load, each of
# its probes printing an outcome for played to read.
class ProfileProcessTest < PokeAccessTest
  # What a play can call: probe prints a block's value as "PROBE name base64(Marshal)", or what it raised; said and
  # cues answer the lines a block says and the sounds it plays, as [file, volume, pitch]. The play's own code goes in
  # methods too: the profile's files are evaluated at the top level, where a local would be the one their hook blocks
  # assign.
  HELPERS = <<-'RUBY'
    def probe(name)
      value = begin
                yield
              rescue StandardError, ScriptError => e
                { :probe_raised => "#{e.class}: #{e.message}" }
              end
      puts "PROBE #{name} #{[Marshal.dump(value)].pack('m0')}"
    end

    def said
      SpeakCapture.clear
      yield
      SpeakCapture.log.dup
    end

    def cues
      log = []
      was = Audio.method(:se_play)
      Audio.define_singleton_method(:se_play) { |*a| log.push([a[0].to_s.split("/").last, a[1], a[2]]); nil }
      yield
      log
    ensure
      Audio.define_singleton_method(:se_play, was)
    end

    probe(:load_errors) { Harness.errors }
    probe(:missing_hooks) { PokeAccess::Hooks.missing - CORE_MISSING }
    probe(:absent_functions) { PokeAccess::Hooks.fn_absent - CORE_ABSENT }
  RUBY

  # The process's share of tools/coverage.rb's measure: the mod's line and branch coverage written beside the test
  # processes' own, as test_helper.rb writes it.
  COVERAGE = <<-'RUBY'
    if ENV["PA_COVERAGE"]
      require "coverage"
      require "json"
      Coverage.setup(:lines => true, :branches => true, :eval => true)
      Coverage.resume
      at_exit do
        root = File.expand_path(Dir.pwd).tr("\\", "/") + "/"
        out = {}
        Coverage.result.each do |path, cov|
          rel = path.tr("\\", "/").sub(root, "")
          next unless rel =~ %r{\A(core|games|plugins|loader)/}
          branches = {}
          (cov[:branches] || {}).each { |cond, targets| targets.each { |t, n| branches["#{cond.inspect}|#{t.inspect}"] = n } }
          out[rel] = { "lines" => cov[:lines], "branches" => branches }
        end
        File.write("#{ENV['PA_COVERAGE']}_#{Process.pid}.json", JSON.generate(out))
      end
    end
  RUBY

  class << self
    # Declares the profile's folder under games/, the world loaded before it and the play run after it.
    def profile(dir, world, play)
      @profile = [dir, world, play]
    end

    # Every probe's outcome by name, the process run once per test process.
    def outcomes
      @outcomes ||= run_profile(*@profile)
    end

    # What the process printed, for a failure's message.
    def output
      outcomes
      @output
    end

    private

    # Runs the world, the load (what the core alone does not bind noted apart) and the play in a gen-6 process, from a
    # file: a script this long does not reach the child whole through a Windows command line.
    def run_profile(dir, world, play)
      support = File.join(Harness::ROOT, "test", "support")
      script = "#{COVERAGE}\nrequire #{File.join(support, 'harness').inspect}\n" \
               "require #{File.join(support, 'poke_builder').inspect}\n#{world}\n" \
               "Harness.load_dir('core')\nCORE_MISSING = PokeAccess::Hooks.missing.dup\n" \
               "CORE_ABSENT = PokeAccess::Hooks.fn_absent.dup\nHarness.load_dir('games/#{dir}')\n" \
               "require #{File.join(support, 'speak_capture').inspect}\n" \
               "SpeakCapture.install\nPokeAccess::Config.language = :es\n#{HELPERS}\n#{play}"
      file = Tempfile.new(["pa_#{dir}", ".rb"])
      begin
        file.write(script)
        file.close
        @output = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, file.path], :err => [:child, :out],
                           :chdir => Harness::ROOT) { |io| io.read }.to_s
      ensure
        file.unlink
      end
      @output.scan(/^PROBE (\S+) (\S*)\r?$/).map { |name, data| [name, Marshal.load(data.unpack1("m0"))] }.to_h
    end
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # A probe's outcome in the profile's process; fails the test when the probe raised or was never reached.
  def played(name)
    found = self.class.outcomes
    flunk "the profile's process never reached #{name}: #{self.class.output[-600, 600] || self.class.output}" unless found.key?(name.to_s)
    value = found[name.to_s]
    flunk "#{name} raised in the profile's process: #{value[:probe_raised]}" if value.is_a?(Hash) && value.key?(:probe_raised)
    value
  end
end
