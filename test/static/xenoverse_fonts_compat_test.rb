require "rbconfig"
require "tmpdir"
require "fileutils"

class XenoverseFontsCompatTest < PokeAccessTest
  test "private font registration, reset interception and both error channels use the real compatibility preload" do
    root = File.expand_path("../..", File.dirname(__FILE__))
    driver = File.join(root, "test/support/xenoverse_fonts_driver.rb")
    compat = File.join(root, "games/xenoverse/compat.rb")
    runtimes = [RbConfig.ruby]
    runtimes.push(ENV["RUBY187"]) if ENV["RUBY187"] && File.file?(ENV["RUBY187"])
    runtimes.uniq.each do |ruby|
      %w[success failure refused log-failure core-log-failure].each do |kind|
        Dir.mktmpdir("pa_xenoverse_fonts") do |dir|
          FileUtils.mkdir_p(File.join(dir, "Fonts"))
          FileUtils.mkdir_p(File.join(dir, "accessibility/data"))
          %w[first.ttf second.OTF README.txt].each { |name| File.binwrite(File.join(dir, "Fonts", name), "Owned inert font fixture") }
          output = IO.popen([{ "RUBYOPT" => nil, "RUBYLIB" => nil }, ruby, driver, compat, kind],
                            :chdir => dir, :err => [:child, :out]) { |io| io.read }
          assert $?.success?, "#{ruby} #{kind}: #{output}"
          assert_match(/PASS\|#{Regexp.escape(kind)}\|\d+\|/, output)
        end
      end
    end
  end
end
