# The "Who's That Fusion?" quiz (FusionQuiz), whose Hoenn copy paints its streak into a sprite of its own instead of
# as HUD text: the streak is said, as painted, each time it changes.
module PokeAccess
  module IF2FusionQuiz
    # The streak line the quiz paints, once per change while its score display is up.
    def self.streak(quiz)
      return unless PokeAccess.ivar(quiz, :@streak_sprite)
      n = PokeAccess.ivar(quiz, :@current_streak).to_i
      PokeAccess::Cursor.announce(quiz, :if2_quiz_streak, n, false) { _INTL("Streak: {1}", n) }
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  after("FusionQuiz", :refresh_streak_ui) { |q, _r, _a| PokeAccess::IF2FusionQuiz.streak(q) }
end
