# Infinite Fusion Hoenn's title and fusion quiz, gamedata pass: the title prompt said before Hoenn's title paints its
# version label, and the quiz's streak said as painted each time it changes.

# Hoenn's title screen, which paints its version label through the HUD reader, as HoennIntroScreen#intro does with
# Kernel.pbDisplayText.
class HoennIntroScreen
  def intro
    PokeAccess::HudText.say("v.1.0.0")
    :shown
  end
end

# The quiz's streak fields and the calls that repaint them.
class FusionQuiz
  def initialize; @current_streak = 0; @streak_sprite = nil; end

  def create_score_display
    @streak_sprite = Object.new
    refresh_streak_ui
  end

  def increase_streak
    @current_streak += 1
    refresh_streak_ui
  end

  def break_streak
    @current_streak = 0
    refresh_streak_ui
  end

  def refresh_streak_ui; :painted; end
end

# The profile's files, loaded after the stand-ins above: a hook on a class not yet defined binds nothing.
%w[title fusion_quiz].each do |f|
  path = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "#{f}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class IfhTitleQuizGdTest < PokeAccessTest
  test "says the title prompt, interrupting, before Hoenn's title paints its version label" do
    SpeakCapture.clear
    HoennIntroScreen.new.intro
    assert_equal [[prompt, true], ["v.1.0.0", false]], SpeakCapture.log
  end

  test "says the prompt again each time the title shows" do
    HoennIntroScreen.new.intro
    SpeakCapture.clear
    HoennIntroScreen.new.intro
    assert_equal [prompt, true], SpeakCapture.log.first
  end

  test "says nothing of the streak before the score display is up" do
    SpeakCapture.clear
    FusionQuiz.new.refresh_streak_ui
    assert_nothing_spoken
  end

  test "says the streak as painted, queued, each time it changes and only then" do
    quiz = FusionQuiz.new
    SpeakCapture.clear
    quiz.create_score_display
    quiz.increase_streak
    quiz.refresh_streak_ui
    quiz.break_streak
    assert_equal [["Streak: 0", false], ["Streak: 1", false], ["Streak: 0", false]], SpeakCapture.log
  end

  private

  # The mod's Spanish text for an i18n key.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # The title prompt with its key hint, as said while key hints are said.
  def prompt
    "#{t(:title_screen)}. #{t(:title_press, :key => t(:key_enter))}"
  end
end
