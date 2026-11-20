module PokeAccess
  # The Clefairy at Rustboro's school blackboard (clefairy_minigame): the arrows to repeat come by message, and then the
  # game reads the arrow keys with only a sound for each one it takes. Each arrow taken is said, cutting in, up to the
  # sequence's length.
  module IF2Clefairy
    # The arrow keys in the order the game checks them, each with its direction code.
    ARROWS = [[Input::LEFT, 4], [Input::UP, 8], [Input::RIGHT, 6], [Input::DOWN, 2]]
    # The sound the game plays as it takes an arrow.
    TAKEN_SE = "GUI save choice"

    # Runs the minigame over a sequence of length arrows, the ones it takes said meanwhile.
    def self.run(length)
      @left = length.to_i
      @pulse = nil
      yield
    ensure
      @left = nil
    end

    # Says the arrow behind the sound the game plays as it takes one: the next of those pressed this pulse, in the
    # order the game checks them.
    def self.taken(se)
      return unless @left && @left > 0
      return unless (se.respond_to?(:name) ? se.name : se).to_s == TAKEN_SE
      pulse = PokeAccess::Frame.pulses
      if pulse != @pulse
        @pulse = pulse
        @used = 0
      end
      arrow = ARROWS.select { |key, _d| Input.trigger?(key) }[@used]
      @used += 1
      @left -= 1
      PokeAccess.speak(PokeAccess::Routes::Text.dir(arrow[1]), true) if arrow
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  kernel("clefairy_minigame", :around) { |a, nxt| PokeAccess::IF2Clefairy.run(a[0] || 4) { nxt.call } }
  kernel("pbSEPlay") { |a, _r| PokeAccess::IF2Clefairy.taken(a[0]) }
end
