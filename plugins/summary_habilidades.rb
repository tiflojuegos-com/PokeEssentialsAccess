# The EV/IV sub-screen ("Habilidades", Accept on the stats page): a third-party resource (credits
# Felidaex & Zardae) pasted identically into the forks that ship it, running a blocking loop no shared
# page hook sees. Read by capture -- the sheet is game text and one of these games ships per-language
# builds. The paint lands before the input loop, so the frame poll inside that loop flushes it. The rows
# are label,value pairs and "0/31" repeats, so they are joined as painted, never uniq'd.
module PokeAccess
  module SummaryHabilidades
    def self.poll
      return unless PokeAccess::PaintCapture.pending?(:sum_habilidades)
      rows = PokeAccess::PaintCapture.take(:sum_habilidades)
      return if rows.nil? || rows.empty?
      PokeAccess.speak_clean(rows.join(", "), false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.before_hook("PokemonSummaryScene", :Habilidades, :optional => true) do |_s, _a|
  PokeAccess::PaintCapture.arm(:sum_habilidades)
end
PokeAccess::Keys.on_frame { PokeAccess::SummaryHabilidades.poll }
