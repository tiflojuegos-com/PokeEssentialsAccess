# Sliding banners (FastItemGet / QuickPickup family; Scene_Map#addSprite in reminiscencia, relict,
# awakening, royal and pokemon_z). A banner is one line painted onto a picture bitmap, with drawTextEx or
# with pbDrawTextPositions, then slid across the map through Scene_Map#addSprite, with no message behind
# it while the map is up (off the map the same functions fall back to pbMessage, which the message reader
# carries). What rides on it differs per game: floor items and gold, the achievement unlocked, the daily
# task, the relationship pops, the boss warning, "egg ready", an autosave mark.
#
# The pairing is by BITMAP: the paint wraps remember what was written on which bitmap, and the banner
# speaks when that same bitmap reaches addSprite. Nothing is composed and nothing depends on timing, so a
# window repainting its own text in the same frame cannot be mistaken for a banner, a banner nested in
# another (Reminiscencia's relationship pop raises the point pop right behind itself) reads both, and the
# line spoken is the one on screen, in the game's own words. A paint with no letter or digit (Awakening's
# autosave asterisk) is not speech and is dropped.
#
# The five copies differ only in what they paint; the sink is the same class, method and signature.
module PokeAccess
  module SlideBanners
    KEEP = 8
    @painted = []

    # Remembers the line drawTextEx just painted on a bitmap; only the last few pairs are kept.
    def self.painted(bitmap, text)
      return if bitmap.nil? || text.nil?
      t = text.to_s
      return unless t =~ /[a-zA-Z0-9]/
      @painted.reject! { |b, _t| b.equal?(bitmap) }
      @painted.push([bitmap, t])
      @painted.shift while @painted.length > KEEP
    rescue StandardError
      nil
    end

    # Remembers a pbDrawTextPositions burst on a bitmap as one line (its rows in paint order).
    def self.painted_rows(bitmap, rows)
      return unless rows.is_a?(Array)
      texts = rows.map { |r| r.is_a?(Array) ? r[0].to_s : nil }.compact.reject { |t| t.strip.empty? }
      painted(bitmap, texts.uniq.join(", ")) unless texts.empty?
    rescue StandardError
      nil
    end

    # Speaks the line painted on a bitmap the map is about to slide in, and forgets it.
    def self.slid(bitmap)
      i = @painted.index { |b, _t| b.equal?(bitmap) }
      return if i.nil?
      PokeAccess.speak_clean(@painted.delete_at(i)[1], false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.wrap_kernel("drawTextEx", "plugin_banner_paint", :before) do |args, _r|
  PokeAccess::SlideBanners.painted(args[0], args[5])
end

PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "plugin_banner_paint_rows", :before) do |args, _r|
  PokeAccess::SlideBanners.painted_rows(args[0], args[1])
end

PokeAccess::Hooks.after_hook("Scene_Map", :addSprite, :optional => true) do |_scene, _r, args|
  PokeAccess::SlideBanners.slid(args[2])
end
