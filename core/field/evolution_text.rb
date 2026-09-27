module PokeAccess
  # Lines the evolution scene writes straight into its message box ("X is evolving!"): while it runs, each new line
  # of the box is said, queued, unless the dialogue reader already said it.
  module EvolutionText
    def self.open(scene)
      @scene = scene
      @last = nil
      @depth = PokeAccess.message_depth
    end

    def self.close
      @scene = nil
    end

    # Says the box's line when it changed and did not come through pbMessageDisplay.
    def self.poll
      return unless @scene
      return if PokeAccess.message_depth > @depth.to_i
      win = PokeAccess.sprite(@scene, "msgwindow")
      t = win ? PokeAccess.clean((win.text rescue "").to_s) : ""
      return if t.empty? || t == @last
      @last = t
      return if t == PokeAccess.clean(PokeAccess.last_dialogue.to_s)
      PokeAccess.speak(t, false, :dialogue)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("PokemonEvolutionScene", :pbEvolution, :optional => true) do |scene, nxt, _a|
  PokeAccess::EvolutionText.open(scene)
  begin
    nxt.call
  ensure
    PokeAccess::EvolutionText.close
  end
end
PokeAccess::Keys.on_frame { PokeAccess::EvolutionText.poll }
