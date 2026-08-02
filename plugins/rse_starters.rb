# RSE starter choice (the Emerald UI Pack's RSESTarterChoice): the three starters as a carousel of Poke
# Balls, chosen with left/right. Nothing is written anywhere -- the species is a sprite and the ball is a
# picture -- so the screen is three identical clicks without a reader.
#
# The mod already covers three other starter pickers; this is a fourth, unrelated implementation. pbUpdate
# runs every frame of the scene's own input loop and repaints only when @index moves, so reading there
# covers both the opening and every move, deduped on the index.
#
# @species_cache holds GameData::Species entries built in initialize, one per starter, parallel to @index.
# Preferring it over @pokemon (the raw ids) is what gets the species' real name in the player's language.
module PokeAccess
  module RSEStarters
    # The focused starter's name, plus where it sits in the row, or nil.
    def self.text(scene)
      idx = PokeAccess.ivar(scene, :@index)
      cache = PokeAccess.ivar(scene, :@species_cache)
      return nil unless idx.is_a?(Integer) && cache.is_a?(Array) && idx >= 0 && idx < cache.length
      nm = (cache[idx].name rescue nil)
      nm = (PokeAccess::Data.species_name(cache[idx]) rescue nil) if nm.nil? || nm.to_s.empty?
      return nil if nm.nil? || nm.to_s.empty?
      PokeAccess::I18n.t(:rse_starter, :name => nm, :n => idx + 1, :tot => cache.length)
    rescue StandardError
      nil
    end

    # Speaks the focused starter when the carousel moves, deduped per scene.
    def self.read(scene)
      PokeAccess::Cursor.announce(scene, :rse_starter, PokeAccess.ivar(scene, :@index), true) { text(scene) }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("RSESTarterChoice", :pbUpdate, :optional => true) do |scene, _r, _a|
  PokeAccess::RSEStarters.read(scene)
end
