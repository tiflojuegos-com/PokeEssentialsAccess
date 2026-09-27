# Infinite Fusion's Pokedex entry pages a long entry ("1/2" beside the text), flipped by the confirm key without
# drawPage: read as it paints, the text and, from medium, the page; and Hoenn's sprite switch on the info page.
module PokeAccess
  module IFEntryPages
    # Says the page a flip painted, from the page's two drawTextEx calls: the "n/m" beside it and the text.
    def self.flipped(painted)
      rows = (painted || []).map { |r| PokeAccess.clean(r.to_s) }.reject { |t| t.empty? }
      marks, texts = rows.partition { |t| t =~ /\A\d+\s*\/\s*\d+\z/ }
      pages = marks.map { |m| m =~ /(\d+)\s*\/\s*(\d+)/ ? PokeAccess::I18n.t(:if_entry_page, :n => $1, :m => $2) : m }
      pages = [] unless PokeAccess::Verbosity.keep?(:positions, :medium)
      line = PokeAccess.sentences(texts.dup.concat(pages))
      PokeAccess.speak(line, true) unless line.empty?
    rescue StandardError
      nil
    end

    # Says what switching the info page's sprite (Q/W, Hoenn) repainted: the sprite's artist line and, when it is
    # not what was last heard, the entry text a fusion's custom entry changes with the sprite.
    def self.switched(scene, painted)
      label = PokeAccess.clean((_INTL("Sprite: {1}", "") rescue "Sprite: ").to_s).strip
      rows = (painted[:positions] || []).map { |r| PokeAccess.clean(r.to_s) }
      sprite = rows.find { |t| !label.empty? && t.index(label) == 0 }
      entry = (painted[:dtex] || []).map { |r| PokeAccess.clean(r.to_s) }
      entry = entry.reject { |t| t.empty? || t =~ /\A\d+\s*\/\s*\d+\z/ }.join(" ")
      parts = [sprite]
      unless entry.empty? || PokeAccess::Cursor.current(scene, :pdx_page).to_s.include?(entry)
        parts.push(entry)
        PokeAccess::Cursor.store(scene, :pdx_page, PokeAccess.sentences([sprite, entry].compact))
      end
      line = PokeAccess.sentences(parts.compact)
      PokeAccess.speak(line, true) unless line.empty?
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  around("PokemonPokedexInfo_Scene", :changeEntryPage, :optional => true) do |_scene, nxt, _a|
    PokeAccess::PaintCapture.arm(:if_entry_page)
    begin
      nxt.call
    ensure
      PokeAccess::IFEntryPages.flipped(PokeAccess::PaintCapture.take_by_source(:if_entry_page)[:dtex])
    end
  end
  around("PokemonPokedexInfo_Scene", :update_displayed_sprite, :optional => true) do |scene, nxt, _a|
    PokeAccess::PaintCapture.arm(:if_sprite_switch)
    begin
      nxt.call
    ensure
      PokeAccess::IFEntryPages.switched(scene, PokeAccess::PaintCapture.take_by_source(:if_sprite_switch))
    end
  end
end
