module PokeAccess
  # Modern summary ribbons page: reads the focused ribbon as the cursor moves over it (gen-6's ribbon page
  # is static, so this is modern-only).
  module RibbonsV21
    # The focused ribbon's name and description, from the modern Ribbon GameData. gen-6 has no interactive
    # ribbon cursor (its summary ribbon page is static), so this is modern-only.
    def self.ribbon_text(id)
      return nil unless id
      r = (GameData::Ribbon.get(id) rescue nil)
      return nil unless r
      PokeAccess::Util.join_parts([(r.name rescue nil), (r.description rescue nil)])
    end
  end
end

# Summary ribbons page: drawSelectedRibbon is called once per cursor move with the focused ribbon id.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryV21::SCENE, :drawSelectedRibbon) do |_s, _r, args|
  t = PokeAccess::RibbonsV21.ribbon_text(args[0])
  PokeAccess.speak(t, true) if t && !t.empty?
end
