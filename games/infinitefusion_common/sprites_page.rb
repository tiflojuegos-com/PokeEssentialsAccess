# Infinite Fusion's alternative sprites page (Pokedex page 3), walked by left and right outside drawPage: which
# sprite, of how many from medium, its artist at full, whether it is in use and, in Hoenn, whether its blacklist keeps
# it out of the random pick.
module PokeAccess
  module IFSpritesPage
    # The line for the sprite in the middle, from the page's own state and the artist it painted.
    def self.text(scene, rows)
      list = PokeAccess.ivar(scene, :@available)
      i = PokeAccess.ivar(scene, :@selected_index)
      return nil unless list.is_a?(Array) && i.is_a?(Integer) && !list.empty?
      whole = PokeAccess::I18n.t(:if_sprite_pos, :n => i + 1, :m => list.length)
      head = PokeAccess::Verbosity.keep?(:positions, :medium) ? whole : PokeAccess::I18n.t(:if_sprite_n, :n => i + 1)
      artist = (rows || []).map { |r| PokeAccess.clean(r.to_s) }.reject { |r| r.empty? }.join(", ")
      main = (scene.is_main_sprite rescue false) ? PokeAccess::I18n.t(:if_sprite_main) : nil
      out = blocked?(scene, list[i]) ? PokeAccess::I18n.t(:if_sprite_excluded) : nil
      PokeAccess::Info.set_info(:text, PokeAccess::Verbosity.full_line([whole, artist, main, out]))
      PokeAccess::Verbosity.line(:dex_page, [[head, :brief], [artist, :full], [main, :brief], [out, :brief]])
    rescue StandardError
      nil
    end

    # Whether a sprite is on its species' blacklist (Hoenn's $PokemonSystem.sprites_blacklist: alt letters by the
    # species getSpecies gives, as the page keeps it); false where the game has none.
    def self.blocked?(scene, sprite)
      bl = ($PokemonSystem.sprites_blacklist rescue nil)
      return false unless bl.is_a?(Hash)
      letters = bl[(getSpecies(PokeAccess.ivar(scene, :@species)).species rescue nil)]
      letters.is_a?(Array) && letters.include?((sprite.alt_letter rescue nil))
    rescue StandardError
      false
    end

    # Says the selected sprite's state after a toggle on the blacklist, which only its icon shows.
    def self.toggled(scene)
      list = PokeAccess.ivar(scene, :@available)
      i = PokeAccess.ivar(scene, :@selected_index)
      return unless list.is_a?(Array) && i.is_a?(Integer) && list[i]
      PokeAccess.speak(PokeAccess::I18n.t(blocked?(scene, list[i]) ? :if_sprite_excluded : :if_sprite_allowed), true)
    end

    # Whether drawing a page arrives at it (from another page or species); a redraw in place is no arrival.
    def self.arrive(scene, page)
      now = [page, PokeAccess.ivar(scene, :@species)]
      was = PokeAccess.ivar(scene, :@access_if_drawn)
      scene.instance_variable_set(:@access_if_drawn, now)
      was != now
    end

    # Runs the sprite chooser (pbChooseAlt, the confirm key on the page), said on the way in, since left and right
    # now change the sprite, not the page; and on the way out, unless the pick closed the whole entry.
    def self.choosing(scene)
      PokeAccess.speak(PokeAccess::I18n.t(:if_sprite_choosing), true)
      begin
        yield
      ensure
        PokeAccess.speak(PokeAccess::I18n.t(:if_sprite_chosen), false) unless PokeAccess.ivar(scene, :@endscene)
      end
    end

    # Captures a paint of the middle sprite, in place of the shared entry reader's capture, and says it if changed.
    def self.capture(scene)
      PokeAccess::PaintCapture.arm(:if_sprites)
      begin
        yield
      ensure
        t = text(scene, PokeAccess::PaintCapture.take(:if_sprites))
        PokeAccess.speak(t, true) if t && PokeAccess::Cursor.changed?(scene, :if_sprite, t)
      end
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  # Page 3 is this page, not the vanilla forms page: the shared entry reader leaves it to the hooks below.
  override("PokeAccess::PokedexInfoV21", :page_id) do |_mod, original, args|
    args[1] == 3 ? :page_other : original.call
  end
  # drawPage: arriving on page 3 (or a new species on it) is read afresh, resetting the shared reader's page slot;
  # arriving at another page drops the sprite the info key held.
  around("PokemonPokedexInfo_Scene", :drawPage, :optional => true) do |scene, nxt, args|
    arrived = PokeAccess::IFSpritesPage.arrive(scene, args[0].to_i)
    PokeAccess::Info.clear_text if arrived && args[0].to_i != 3
    next nxt.call unless args[0].to_i == 3
    if arrived
      PokeAccess::Cursor.reset(scene, :if_sprite)
      PokeAccess::Cursor.reset(scene, :pdx_page)
    end
    PokeAccess::IFSpritesPage.capture(scene) { nxt.call }
  end
  # Left and right on the page, outside drawPage.
  around("PokemonPokedexInfo_Scene", :update_displayed, :optional => true) do |scene, nxt, _a|
    PokeAccess::IFSpritesPage.capture(scene) { nxt.call }
  end
  # The sprite chooser's own loop, its left and right read by update_displayed above.
  around("PokemonPokedexInfo_Scene", :pbChooseAlt, :optional => true) do |scene, nxt, _a|
    PokeAccess::IFSpritesPage.choosing(scene) { nxt.call }
  end
  # Hoenn's blacklist toggle, run unguarded as the refusal it may show is a message.
  after("PokemonPokedexInfo_Scene", :toggle_sprite_blacklist, :optional => true, :hook_container => true) do |s, _r, _a|
    PokeAccess::IFSpritesPage.toggled(s)
  end
end
