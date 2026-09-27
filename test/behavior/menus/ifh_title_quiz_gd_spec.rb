# Infinite Fusion Hoenn's title screen and the fusion quiz's streak, gamedata pass. The title stand-in paints its
# version label through the HUD reader, as HoennIntroScreen#intro does with Kernel.pbDisplayText; the quiz stand-in
# keeps the quiz's streak fields. Both come before the profile files load.
class HoennIntroScreen
  def intro
    PokeAccess::HudText.say("v.1.0.0")
    :shown
  end
end

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

%w[title fusion_quiz].each do |f|
  load File.expand_path("../../../games/infinitefusion_hoenn/#{f}.rb", File.dirname(__FILE__))
end

Suite.define("ifh title: Hoenn's own title screen says the title prompt, then its version label") do
  SpeakCapture.clear
  HoennIntroScreen.new.intro
  eq "the prompt first, interrupting, the version queued after it", SpeakCapture.log,
     [[PokeAccess::TitleScreen.prompt, true], ["v.1.0.0", false]]
end

Suite.define("ifh fusion quiz: the streak it paints is said whenever it changes") do
  quiz = FusionQuiz.new
  SpeakCapture.clear
  quiz.refresh_streak_ui
  silent "nothing before the score display is up"
  quiz.create_score_display
  quiz.increase_streak
  quiz.refresh_streak_ui
  quiz.break_streak
  eq "each change, queued, as painted", SpeakCapture.log,
     [["Streak: 0", false], ["Streak: 1", false], ["Streak: 0", false]]
end
