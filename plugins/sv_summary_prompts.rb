# The SV Summary Screen's two special-key panels (held item, ability): their paint, captured as they open and said
# on the first frame of their own loop, interrupting; the Close button, painted first, said last while hints are on.
module PokeAccess
  module SVSummaryPrompts
    def self.arm
      @pending = true
      PokeAccess::PaintCapture.arm(:sv_prompt)
    end

    def self.flush
      return unless @pending
      @pending = false
      rows = PokeAccess::PaintCapture.take_by_source(:sv_prompt) || {}
      pos = rows[:positions] || []
      said = pos[1..-1].to_a.concat(rows[:dtex] || [])
      said.concat(pos[0, 1]) if PokeAccess::Verbosity.hints?
      t = PokeAccess.sentences(said.map { |r| PokeAccess.clean(r.to_s) }.uniq)
      PokeAccess.speak(t, true) unless t.empty?
    end
  end
end

[:pbItemPrompt, :pbAbilityPrompt].each do |m|
  PokeAccess::Hooks.before_hook("PokemonSummary_Scene", m, :optional => true) { |_s, _a| PokeAccess::SVSummaryPrompts.arm }
end
# Flushed from the frame poller, which the panel's loop reaches through Input.update on its first frame.
PokeAccess::Keys.on_frame { PokeAccess::SVSummaryPrompts.flush }
