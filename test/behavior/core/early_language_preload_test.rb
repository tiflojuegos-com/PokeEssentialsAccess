require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"

class EarlyLanguagePreloadTest < PokeAccessTest
  CASES = %w[selection repeated_preload init_failure speak_failure optional_braille
             invisible inactive disposed wrong_commands negative_index high_index ambiguous].freeze

  CASES.each do |case_name|
    test "early language preload preserves #{case_name} and normal boot" do
      runtimes = [RbConfig.ruby]
      legacy = ENV["RUBY187"]
      runtimes.push(legacy) if legacy && File.file?(legacy) && !runtimes.include?(legacy)
      runtimes.each do |ruby|
        Dir.mktmpdir("pa_early_language") do |folder|
          FileUtils.mkdir_p(File.join(folder, "accessibility", "data"))
          File.binwrite(File.join(folder, "accessibility", "boot.rb"), "$boots += 1\n")
          File.binwrite(File.join(folder, "preload_access.rb"),
                       File.binread(File.join(Harness::ROOT, "loader", "preload_access.rb")))
          driver = File.join(Harness::ROOT, "test", "support", "bootstrap_language_driver.rb")
          output, errors, status = Open3.capture3({"RUBYOPT" => nil, "RUBYLIB" => nil}, ruby,
                                                driver, "preload_access.rb", case_name, :chdir => folder)
          assert status.success?, "#{case_name} (#{ruby}): #{errors}#{output}"
          fields = output.strip.split("|")
          assert_equal ["PASS", case_name], fields[0, 2], output
          assert_operator fields[2].to_i, :>=, 8, output
          assert_match(/\A\d+\.\d+/, fields[3].to_s, output)
        end
      end
    end
  end
end
