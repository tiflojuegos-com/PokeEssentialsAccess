module PokeAccess
  # Modern summary ribbons page: reads the focused ribbon as the cursor moves over it. The text itself is
  # Summary.ribbon_text, shared with the one gen-6 game (Awakening) that keeps the same cursor over
  # PBRibbons; what is modern here is the shape of the redraw call.
  module RibbonsV21
    # The ribbon the cursor is on, from either shape of the redraw. Vanilla passes the id itself. The
    # Improved Mementos plugin turns the page into a paged grid and passes (filter, index, page, maxpage),
    # where the focused entry is filter[page * PAGE_SIZE + index]. Handing that whole filter Array to
    # GameData::Ribbon.get raised, the rescue swallowed it, and the page said nothing on any cursor move.
    # With no PAGE_SIZE to read, the index alone still resolves the first page rather than nothing.
    def self.focused_id(args)
      return args[0] if args.length < 2
      filter = args[0]
      return nil unless filter.is_a?(Array)
      size = (PokeAccess.const_at("MementoSprite::PAGE_SIZE") || 0).to_i
      filter[(args[2].to_i * size) + args[1].to_i]
    rescue StandardError
      nil
    end
  end
end

# Summary ribbons page: drawSelectedRibbon is called once per cursor move over the focused ribbon.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryV21::SCENE, :drawSelectedRibbon) do |_s, _r, args|
  t = PokeAccess::Summary.ribbon_text(PokeAccess::RibbonsV21.focused_id(args))
  PokeAccess.speak(t, true)
end
