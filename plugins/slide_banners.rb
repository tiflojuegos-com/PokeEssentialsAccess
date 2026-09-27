# Sliding banners (FastItemGet / QuickPickup family, Scene_Map#addSprite): the text painted on a bitmap with
# drawTextEx or pbDrawTextPositions is spoken when that same bitmap reaches addSprite.
module PokeAccess
  module SlideBanners
    KEEP = 8
    @painted = []

    # Remembers the line painted on a bitmap (the last KEEP pairs); one with no letter or digit is dropped.
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
