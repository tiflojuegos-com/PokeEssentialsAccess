module PokeAccess
  # Modern summary ribbons page: the focused ribbon as the cursor moves (Summary.ribbon_cell_text).
  module RibbonsV21
    # The ribbon under the cursor: the id itself, or from Improved Mementos' (filter, index, page, maxpage) the
    # entry filter[page * PAGE_SIZE + index] (the index alone without PAGE_SIZE).
    def self.focused_id(args)
      return args[0] if args.length < 2
      filter = args[0]
      return nil unless filter.is_a?(Array)
      size = (PokeAccess.const_at("MementoSprite::PAGE_SIZE") || 0).to_i
      filter[(args[2].to_i * size) + args[1].to_i]
    rescue StandardError
      nil
    end

    # The line for the ribbon cell the cursor is on: the ribbon's name and description, and where the cell is.
    # A plugin whose grid paints more about the focused entry replaces this.
    def self.focused_text(scene, args)
      PokeAccess::Summary.ribbon_cell_text(scene, focused_id(args))
    end
  end
end

# Summary ribbons page: drawSelectedRibbon is called once per cursor move over the focused ribbon.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryV21::SCENE, :drawSelectedRibbon) do |scene, _r, args|
  PokeAccess.speak(PokeAccess::RibbonsV21.focused_text(scene, args), true)
end
