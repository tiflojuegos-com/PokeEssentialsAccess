# Additional cases for the upstream TitleScreensTest fixture and its real Hooks chain.
# title_screens_test.rb supplies with_title and prompt; run_all loads both files.
class TitleScreensTest < PokeAccessTest
  test "Luka's first style waits for its separate intro before announcing readiness" do
    style = Class.new do
      attr_reader :during_intro
      def initialize; end
      def intro
        @during_intro = SpeakCapture.log.dup
        :ready
      end
    end
    with_title([["GenOneStyle", style]], ["plugins/luka_title.rb"]) do
      screen = GenOneStyle.new
      assert_nothing_spoken
      assert_equal :ready, screen.intro
      assert_equal [], screen.during_intro
      assert_equal [[prompt, false]], SpeakCapture.log
    end
  end

  test "Luka's first intro preserves nested readers before its readiness prompt" do
    child = Class.new { def read; :read; end }
    style = Class.new do
      def intro
        TitleReadyChild.new.read
        :ready
      end
    end
    with_title([["GenOneStyle", style], ["TitleReadyChild", child]], ["plugins/luka_title.rb"]) do
      PokeAccess::Hooks.after_hook("TitleReadyChild", :read) do |_s, _r, _a|
        PokeAccess.speak("Nested intro message", false)
      end
      assert_equal :ready, GenOneStyle.new.intro
      assert_equal [["Nested intro message", false], [prompt, false]], SpeakCapture.log
    end
  end

  test "a failed first-style intro preserves its exception and announces no readiness" do
    style = Class.new do
      def intro; raise "original intro failure"; end
    end
    with_title([["GenOneStyle", style]], ["plugins/luka_title.rb"]) do
      error = assert_raises(RuntimeError) { GenOneStyle.new.intro }
      assert_equal "original intro failure", error.message
      assert_nothing_spoken
    end
  end

  test "reopening the first-style title announces each completed intro once" do
    style = Class.new { def intro; :ready; end }
    with_title([["GenOneStyle", style]], ["plugins/luka_title.rb"]) do
      2.times { assert_equal :ready, GenOneStyle.new.intro }
      assert_equal [[prompt, false], [prompt, false]], SpeakCapture.log
    end
  end
end
