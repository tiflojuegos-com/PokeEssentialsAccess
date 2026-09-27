module PokeAccess
  # The Pokedex form page of the engine Reborn, Rejuvenation and Desolation share (PokedexFormScene): pbUpdate paints
  # the species, then its form and gender on one row, on opening and after each change the chooser makes; the page
  # has no pbRefresh for the gen-6 reader. What it paints is said.
  module DexFormsRV
    # The painted rows in reading order, the form and the gender that share a row apart.
    def self.painted_text(pairs)
      parts = PokeAccess::PaintCapture.laid_out(pairs).map { |r| r.to_s.split(/\s{3,}/) }.flatten
      parts.map { |p| PokeAccess.clean(p) }.reject { |p| p.empty? }.join(", ")
    end

    # Hooks the page's paint.
    def self.bind
      PokeAccess::Hooks.around_hook("PokedexFormScene", :pbUpdate, :optional => true) do |_scene, nxt, _a|
        r = nil
        t = PokeAccess::DexFormsRV.painted_text(PokeAccess::PaintCapture.sample { r = nxt.call })
        PokeAccess.speak(t, true) unless t.empty?
        r
      end
    end
  end
end

PokeAccess::DexFormsRV.bind if PokeAccess::DataRV.engine?
