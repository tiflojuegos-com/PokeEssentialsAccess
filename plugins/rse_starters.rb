# The Emerald UI Pack's starter carousel (RSESTarterChoice), read from pbUpdate: the starter under @index in
# @species_cache (GameData::Species entries) and the category line the screen paints, after the message its
# window shows from the opening.
module PokeAccess
  module RSEStarters
    # The message the scene paints in its window as it opens (the call's own text), said queued.
    def self.opening(scene)
      t = PokeAccess.clean((PokeAccess.sprite(scene, "messageWindow").text rescue nil).to_s)
      t = PokeAccess.clean(PokeAccess.ivar(scene, :@message).to_s) if t.empty?
      PokeAccess.speak(t, false) unless t.empty?
    rescue StandardError
      nil
    end

    # The focused starter's name and place in the row, with its category while the screen shows it, or nil.
    def self.text(scene)
      idx = PokeAccess.ivar(scene, :@index)
      cache = PokeAccess.ivar(scene, :@species_cache)
      return nil unless idx.is_a?(Integer) && cache.is_a?(Array) && idx >= 0 && idx < cache.length
      nm = (cache[idx].name rescue nil)
      nm = (PokeAccess::Data.species_name(cache[idx]) rescue nil) if nm.nil? || nm.to_s.empty?
      return nil if nm.nil? || nm.to_s.empty?
      line = PokeAccess::Verbosity.list_entry(nm, idx + 1, cache.length)
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

    # Speaks the focused starter when the carousel moves, keyed on the sprite's visibility too (the category line);
    # the first read is queued behind the opening message.
    def self.read(scene)
      key = [PokeAccess.ivar(scene, :@index), (PokeAccess.sprite(scene, "pokemon").visible rescue nil)]
      PokeAccess::Cursor.announce(scene, :rse_starter, key, true, false) { text(scene) }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("RSESTarterChoice", :pbStartScene, :optional => true) do |scene, _r, _a|
  PokeAccess::RSEStarters.opening(scene)
end
PokeAccess::Hooks.after_hook("RSESTarterChoice", :pbUpdate, :optional => true) do |scene, _r, _a|
  PokeAccess::RSEStarters.read(scene)
end
