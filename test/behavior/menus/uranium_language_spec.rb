require "rbconfig"

# Uranium's language picker driven through a loop shaped as its own, in a process of its own: the painted title and
# language names, then the painted question with its two picture buttons.
module UraniumLanguageSpec
  # The key feed and a LanguageSelection shaped as Uranium's, declared before the toolkit loads so its hooks find it.
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

  # The checks, run after the load; each prints "CHECK label|ok|detail".
  CHECKS = <<-'RUBY'
    def check(label, ok, detail = nil); puts "CHECK #{label}|#{ok ? 1 : 0}|#{detail.inspect}"; end
    T = PokeAccess::I18n
    check "loads whole", ERRS.empty?, ERRS.first(3)
    mine = %w[LanguageSelection#drawSelection LanguageSelection#update LanguageSelection#confirm LanguageSelection#drawConfirm]
    check "every picker hook binds", (PokeAccess::Hooks.missing & mine).empty?, PokeAccess::Hooks.missing & mine

    UraKeys.feed([:none, Input::DOWN, Input::C, :none, Input::RIGHT, Input::LEFT, Input::C, Input::UP, Input::C,
                  Input::RIGHT, Input::C])
    SpeakCapture.clear
    r = LanguageSelection.new.main
    yes = T.t(:ura_lang_yes)
    no = T.t(:ura_lang_no)
    want = ["Play the game in...", "English", "Español", "Play the game in Español? #{no}", yes, no, "Español",
            "English", "Play the game in English? #{no}", yes]
    check "title and language, the question with its buttons, and the list again after declining",
          [r, SpeakCapture.lines] == [0, want], [r, SpeakCapture.lines]
    check "the opening read is queued", SpeakCapture.log[0, 2] == [["Play the game in...", false], ["English", false]],
          SpeakCapture.log[0, 2]
  RUBY

  # Runs the world, the load and the checks in a gen-6 process: [[label, ok, detail], ...], or the raw output.
  def self.run
    support = File.join(Harness::ROOT, "test", "support")
    script = "require #{File.join(support, 'harness').inspect}\n#{WORLD}\n" \
             "ERRS = Harness.load_all('uranium')\n" \
             "require #{File.join(support, 'speak_capture').inspect}\n" \
             "SpeakCapture.install\nPokeAccess::Config.language = :es\n#{CHECKS}"
    out = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, "-e", script], :err => [:child, :out]) { |io| io.read }
    rows = out.to_s.scan(/^CHECK (.*?)\|([01])\|(.*)$/)
    rows.empty? ? out.to_s : rows
  end
end

Suite.define("uranium language picker: title, language names, and the question with its two buttons") do
  rows = UraniumLanguageSpec.run
  if rows.is_a?(String)
    truthy "the picker process ran its checks: #{rows[0, 300]}", false
  else
    truthy "every check ran (#{rows.length})", rows.length >= 4
    rows.each { |label, ok, detail| Assert.check(label, ok == "1", detail) }
  end
end
