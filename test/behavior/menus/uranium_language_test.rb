require "rbconfig"
require "json"

# Uranium's language picker, driven through a loop shaped as its own in a gen-6 process of its own (its hooks bind to
# the class as the profile loads): the painted title and language names, then the painted question with its two
# picture buttons, and the list again once the question ends.
class UraniumLanguageTest < PokeAccessTest
  # The key feed and a LanguageSelection shaped as Uranium's, declared before the toolkit loads so its hooks find it;
  # with $ura_blank_question set, drawConfirm paints nothing.
  WORLD = <<-'RUBY'
    module UraKeys
      def self.feed(list); @frames = list.dup; @cur = nil; end
      def self.step; @cur = (@frames || []).shift; end
      def self.cur; @cur; end
    end
    class << Input
      def update; UraKeys.step; end
      def trigger?(k); UraKeys.cur == k; end
      def repeat?(k); UraKeys.cur == k; end
    end
    LANGUAGES = [["English", "english.dat"], ["Español", "spanish.dat"], ["Français", "french.dat"]]
    class LanguageSelection
      def languageName(index = nil)
        index = @selection if index.nil?
        LANGUAGES[@options[index]][0]
      end
      def update
        textPositions = []
        for i in 0...[5, @options.length].min
          textPositions.push([languageName(@scroll + i), 256, 152 + (i * 48), 2, nil, nil])
        end
        pbDrawTextPositions(nil, textPositions)
      end
      def drawConfirm
        return if $ura_blank_question
        pbDrawTextPositions(nil, [[_INTL("Play the game in {1}?", languageName), 256, 140, 2, nil, nil]])
      end
      def drawSelection
        @sprites = {}
        pbDrawTextPositions(nil, [[_INTL("Play the game in..."), 320, 108, false, nil, nil]])
        self.update
      end
      def confirm
        @accept = false
        drawConfirm
        loop do
          Graphics.update
          Input.update
          return false if UraKeys.cur.nil?
          if Input.repeat?(Input::LEFT)
            if @accept
              @accept = false
              drawConfirm
            end
          elsif Input.repeat?(Input::RIGHT)
            if !@accept
              @accept = true
              drawConfirm
            end
          elsif Input.trigger?(Input::C)
            return @accept
          elsif Input.trigger?(Input::B)
            return false
          end
        end
      end
      def pbEndScene; nil; end
      def main(firstTimeSetup = false)
        @options = (0...LANGUAGES.length).to_a
        @selection = 0
        @scroll = 0
        ret = 0
        drawSelection
        loop do
          Graphics.update
          Input.update
          self.update
          break if UraKeys.cur.nil?
          if Input.repeat?(Input::DOWN)
            @selection += 1 if @selection < @options.length - 1
          elsif Input.repeat?(Input::UP)
            @selection -= 1 if @selection > 0
          elsif Input.trigger?(Input::C)
            if confirm()
              ret = @options[@selection]
              break
            end
          elsif Input.trigger?(Input::B)
            break if !firstTimeSetup
          end
        end
        pbEndScene
        ret
      end
    end
  RUBY

  # Each run of the picker: one key per frame (:none an idle frame; the feed running out ends the question and the
  # list) and whether the question goes unpainted.
  RUNS = {
    "opened" => [[:none], false],
    "moved" => [["DOWN", "DOWN", "DOWN", "UP"], false],
    "asked" => [["C", "RIGHT", "RIGHT", "LEFT"], false],
    "declined" => [["DOWN", "C", "B"], false],
    "asked twice" => [["C", "B", "C"], false],
    "accepted" => [["DOWN", "C", "RIGHT", "C"], false],
    "unpainted" => [["C", "RIGHT"], true]
  }

  # Runs every picker after the load and prints, as one JSON line, their results with what the nets caught.
  RUNNER = <<-'RUBY'
    keys = lambda { |names| names.map { |n| n.is_a?(String) ? Input.const_get(n) : n } }
    out = { "errors" => ERRS, "missing" => PokeAccess::Hooks.missing.grep(/\ALanguageSelection#/), "runs" => {} }
    RUNS.each do |name, (feed, blank)|
      $ura_blank_question = blank
      UraKeys.feed(keys.call(feed))
      SpeakCapture.clear
      ret = LanguageSelection.new.main
      out["runs"][name] = { "ret" => ret, "log" => SpeakCapture.log.map { |text, cut| [text, cut] } }
    end
    out["raw"] = SpeakCapture.raw_offenders.map { |_test, text| text }
    out["arity"] = ArityNet.offenders
    puts "RESULT #{JSON.generate(out, :ascii_only => true)}"
  RUBY

  test "opens saying the painted title and the focused language, both queued" do
    assert_equal [["Play the game in...", false], ["English", false]], picker("opened")["log"]
  end

  test "says each language the cursor moves to by the name the list paints, once per move" do
    assert_equal [["Español", true], ["Français", true], ["Español", true]], after_opening("moved")
  end

  test "asks the painted question with the focused button, then says each button the choice moves to" do
    assert_equal [["Play the game in English? #{no}", true], [yes, true], [no, true], ["English", true]],
                 after_opening("asked")
  end

  test "back on the list after declining, says the focused language again" do
    assert_equal [["Español", true], ["Play the game in Español? #{no}", true], ["Español", true]],
                 after_opening("declined")
  end

  test "confirming again in the same picker asks the painted question again with its focused button" do
    question = ["Play the game in English? #{no}", true]
    assert_equal [question, ["English", true], question, ["English", true]], after_opening("asked twice")
  end

  test "accepting picks the language focused" do
    assert_equal [1, [["Español", true], ["Play the game in Español? #{no}", true], [yes, true]]],
                 [picker("accepted")["ret"], after_opening("accepted")]
  end

  test "a question that paints nothing leaves the focused button alone" do
    assert_equal [[no, true], [yes, true], ["English", true]], after_opening("unpainted")
  end

  private

  def yes; PokeAccess::I18n.t(:ura_lang_yes); end

  def no; PokeAccess::I18n.t(:ura_lang_no); end

  # A run's speech past the opening's two lines.
  def after_opening(name)
    picker(name)["log"][2..-1]
  end

  # One picker run's {"ret", "log"}; flunks when the process failed to load the profile whole, left a picker hook
  # unbound or tripped a net.
  def picker(name)
    all = outcome
    problems = all.reject { |k, v| k == "runs" || v.empty? }
    flunk "the picker process: #{problems.inspect}" unless problems.empty?
    all["runs"][name] or flunk "the picker process reported no run #{name}"
  end

  # What the picker process printed, run once per test process: {"errors", "missing", "raw", "arity", "runs"}.
  def outcome
    self.class.instance_variable_get(:@outcome) || self.class.instance_variable_set(:@outcome, spawn_picker)
  end

  # Runs the world, the uranium profile's load and every picker in a gen-6 process, the mod's speech captured in
  # Spanish and the arity net on; flunks with the process's output when it prints no result.
  def spawn_picker
    support = File.join(Harness::ROOT, "test", "support")
    script = "require #{File.join(support, 'harness').inspect}\nrequire 'json'\n#{WORLD}\n" \
             "ERRS = Harness.load_all('uranium')\n" \
             "require #{File.join(support, 'speak_capture').inspect}\n" \
             "require #{File.join(support, 'arity_net').inspect}\n" \
             "SpeakCapture.install\nPokeAccess::Config.language = :es\n" \
             "RUNS = #{RUNS.inspect}\n#{RUNNER}"
    out = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, "-e", script], :err => [:child, :out]) { |io| io.read }
    line = out.to_s[/^RESULT (.*?)\r?$/, 1]
    flunk "the picker process printed no result: #{out.to_s[0, 400]}" unless line
    JSON.parse(line)
  end
end
