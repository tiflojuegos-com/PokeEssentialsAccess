# RSE starter choice (the Emerald UI Pack's RSESTarterChoice): three starters as a carousel of Poke Balls,
# chosen with left/right. Ball and species are pictures; the only writing is a name and a "<category>
# Pokemon" line painted once the ball opens, and none of it reaches a window reader.
#
# pbUpdate runs every frame of the scene's input loop and repaints only when @index moves, so it covers the
# opening and every move. @species_cache holds the GameData::Species entries parallel to @index, which is
# what gets the real name in the player's language.
module PokeAccess
  module RSEStarters
    # The focused starter's name, category and place in the row, or nil. The category is printed only while
    # the sprite is hidden, which is while the player is choosing, so it is spoken under that condition.
    def self.text(scene)
      idx = PokeAccess.ivar(scene, :@index)
      cache = PokeAccess.ivar(scene, :@species_cache)
      return nil unless idx.is_a?(Integer) && cache.is_a?(Array) && idx >= 0 && idx < cache.length
      nm = (cache[idx].name rescue nil)
      nm = (PokeAccess::Data.species_name(cache[idx]) rescue nil) if nm.nil? || nm.to_s.empty?
      return nil if nm.nil? || nm.to_s.empty?
      line = PokeAccess::I18n.t(:rse_starter, :name => nm, :n => idx + 1, :tot => cache.length)
      cat = category(scene, cache[idx])
      cat ? "#{line}. #{cat}" : line
    rescue StandardError
      nil
    end

    # The "<category> Pokemon" line, only while the screen is showing it.
    def self.category(scene, species)
      shown = (PokeAccess.sprite(scene, "pokemon").visible rescue true)
      return nil if shown
      c = (species.category rescue nil)
      (c.nil? || c.to_s.empty?) ? nil : PokeAccess::I18n.t(:rse_category, :cat => c)
    rescue StandardError
      nil
    end

    # Speaks the focused starter when the carousel moves, deduped per scene. The sprite's visibility is in
    # the key: opening the ball swaps the category line for the sprite, and that is a change worth hearing.
    def self.read(scene)
      key = [PokeAccess.ivar(scene, :@index), (PokeAccess.sprite(scene, "pokemon").visible rescue nil)]
      PokeAccess::Cursor.announce(scene, :rse_starter, key, true) { text(scene) }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("RSESTarterChoice", :pbUpdate, :optional => true) do |scene, _r, _a|
  PokeAccess::RSEStarters.read(scene)
end
