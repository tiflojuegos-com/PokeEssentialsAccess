# Sliding banners (FastItemGet / QuickPickup family; Scene_Map#addSprite in five games): one line painted
# onto a picture bitmap with drawTextEx or pbDrawTextPositions, then slid across the map, with no message
# behind it while the map is up. The pairing is by BITMAP: the paint wraps remember what was written on
# which bitmap, and the banner speaks when that same bitmap reaches addSprite, so nothing is composed, a
# banner nested in another reads both, and a paint with no letter or digit (an autosave asterisk) is dropped.
# The five copies differ only in what they paint.
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
