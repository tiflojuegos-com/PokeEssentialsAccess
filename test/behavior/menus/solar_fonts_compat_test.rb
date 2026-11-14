require "open3"
require "rbconfig"
require "tmpdir"

class SolarFontsCompatTest < PokeAccessTest
  test "Solar privately registers bundled fonts and prevents the old system installer" do
    probe(false)
  end

  test "an unavailable font API is logged before PEA loads and does not restore the system installer" do
    probe(true)
  end

  private

  # Runs the preload alone: a simulated font API can register privately or fail, without touching Windows fonts.
  def probe(fail_api)
    Dir.mktmpdir("pa_solar_fonts") do |dir|
      Dir.mkdir(File.join(dir, "Fonts"))
      File.binwrite(File.join(dir, "Fonts", "sample.ttf"), "fixture; no real font API is called")
      program = <<~'RUBY'
        $calls = []
        class Win32API
          def initialize(*_args)
            raise "font registration unavailable" if ARGV[1] == "fail"
          end
          def call(*args); $calls.push(args); 1; end
        end
        load ARGV[0]
        def FontInstaller.install; raise "system installer executed"; end
        FontInstaller.install
        if ARGV[1] == "fail"
          raise "font failure was lost" unless File.read("accessibility/compat_fonts.txt").include?("font registration unavailable")
        else
          raise "private font flags were lost" unless $calls.length == 1 && $calls[0][1] == 0x10
          raise "unexpected font error" if File.exist?("accessibility/compat_fonts.txt")
        end
        puts "Private fonts checked; no system installer"
      RUBY
      script = File.join(dir, "probe.rb")
      File.binwrite(script, program)
      compat = File.join(Harness::ROOT, "games", "solar_light_lunar_dark", "compat.rb")
      ruby = ENV["ESSENTIAL_TEST_LEGACY_RUBY"] || RbConfig.ruby
      output, errors, status = Open3.capture3(ruby, script, compat, fail_api ? "fail" : "ok", :chdir => dir)
      assert status.success?, errors + output
      assert_includes output, "Private fonts checked; no system installer"
    end
  end
end
