# Infinite Fusion's Art Gallery (displayGalleryFrame, in the credits code of both games): a frame's message gives the
# fusion's name and its artist, and only the sprite shows what it is fused from, so its head and body follow that
# message. The frames are events without a graphic, so the locator names each by its place in the exhibition.
module PokeAccess
  module IFGallery
    FEATURED = 260
    CALL = /displayGalleryFrame\s*\(/
    SLOT = /frame\s*=\s*(\d+)/

    @slots = {}

    # The head and body of the sprite hung in frame i (VAR_GALLERY_FEATURED_SPRITES), or nil for an empty frame or a
    # Pokemon that is not a fusion.
    def self.parts(i)
      sprites = $game_variables[FEATURED]
      sprite = sprites.is_a?(Array) ? sprites[i.to_i] : nil
      return nil unless sprite.respond_to?(:head_id) && sprite.respond_to?(:body_id)
      return nil if (sprite.type rescue nil) == :BASE
      sp = getPokemonSpeciesFromPifSprite(sprite)
      head = (sp.head_pokemon.name rescue nil)
      body = (sp.body_pokemon.name rescue nil)
      head && body ? PokeAccess::I18n.t(:if_gal_parts, :head => head, :body => body) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Promises frame i's head and body for after the message that names it.
    def self.frame_shown(i)
      line = parts(i)
      PokeAccess.also_after_next_line(line) if line
    end

    # The frame an event shows (its script sets frame and calls displayGalleryFrame), or nil; kept per map and event.
    def self.slot(ev)
      key = [($game_map.map_id rescue 0), (ev.id rescue 0)]
      return @slots[key] if @slots.key?(key)
      text = PokeAccess::Routes::Effects.script_text(ev)
      m = text =~ CALL ? text.match(SLOT) : nil
      @slots[key] = m ? m[1].to_i : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A frame's name in the locator, or nil for any other event.
    def self.frame_name(ev)
      s = slot(ev)
      s ? PokeAccess::I18n.t(:if_gal_frame, :n => s + 1) : nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  kernel("displayGalleryFrame", :before) { |args, _r| PokeAccess::IFGallery.frame_shown(args[0]) }
  event_name { |ev| PokeAccess::IFGallery.frame_name(ev) }
end
