# Photo album (the "Fotos del equipo" plugin, AlbumFotos_Scene): a 2x2 grid of saved screenshots over
# pages, cursor in @photo (0-3) and @page, with @viendofoto set while one is enlarged. The photos are
# screenshots -- no text to read -- so what a player can actually use is the slot's number and the date,
# which the plugin stores in the FILENAME as capture###_dd_mm_yyyy.png.
#
# pbUpdateAlbum is a modal `loop do` in both copies (it calls Input.update every iteration), so the cursor
# is polled each frame through SceneWatcher rather than hooked.
#
# Here the copies genuinely diverge, and this is where a shared reader has to ask instead of assume: one
# added per-save-slot folders and keeps the directory listing in a cache behind obtener_archivo_captura,
# the other has no such method and globs a fixed ALBUM_DIR inline. Calling the missing method would have
# left the second game announcing "empty slot" for every photo it owns. The naming scheme is the same in
# both, so only the LOOKUP differs -- and the fallback caches its own listing, because this runs per frame
# and a directory scan at 60fps is not something to hand a player.
module PokeAccess
  module PhotoAlbum
    # The album's files, listed once per scene. The plugin does not add photos while the album is open.
    def self.files(scene)
      cached = PokeAccess.ivar(scene, :@pa_album_files)
      return cached if cached.is_a?(Array)
      dir = (::ALBUM_DIR rescue "Fotos")
      list = (Dir.glob(File.join(dir, "capture*.png")).sort rescue [])
      scene.instance_variable_set(:@pa_album_files, list)
      list
    end

    # The file behind a slot, by whichever route this copy of the plugin offers, or nil for an empty slot.
    def self.file_for(scene, index)
      if scene.respond_to?(:obtener_archivo_captura, true)
        # respond_to? already said the method is there, so a raise here is a real fault and not the usual
        # cross-copy variance. Swallowing it silently would report every photo as an empty slot.
        return (scene.send(:obtener_archivo_captura, index) rescue (PokeAccess.log_once("album_lookup", $!); nil))
      end
      tag = sprintf("capture%03d", index)
      files(scene).find { |f| f.include?(tag) }
    end

    # The dd/mm/yyyy stamp a capture filename ends with, or nil when it has none.
    def self.date_of(file)
      parts = File.basename(file.to_s, ".png").split("_")
      return nil if parts.length < 3
      "#{parts[-3]}/#{parts[-2]}/#{parts[-1]}"
    end

    # What the focused slot is: a numbered photo with its date, or an empty slot, always with the page.
    def self.text(scene)
      page  = PokeAccess.ivar_i(scene, :@page)
      photo = PokeAccess.ivar_i(scene, :@photo)
      pages = (PokeAccess.ivar(scene, :@numpages) || 1).to_i
      index = page * 4 + photo
      file  = file_for(scene, index)
      head = if file
               d = date_of(file)
               t = PokeAccess::I18n.t(:alb_photo, :n => index + 1, :tot => PokeAccess.ivar_i(scene, :@numcapturas))
               d ? "#{t}, #{d}" : t
             else
               PokeAccess::I18n.t(:alb_empty)
             end
      "#{head}, #{PokeAccess::I18n.t(:alb_page, :n => page + 1, :tot => pages)}"
    end
  end

  PhotoAlbumReader = SceneWatcher.reader("AlbumFotos_Scene", :pbUpdateAlbum, :photo_album) do |s|
    viewing = (s.instance_variable_get(:@viendofoto) rescue false)
    [[PokeAccess.ivar_i(s, :@page), PokeAccess.ivar_i(s, :@photo), viewing],
     lambda { PokeAccess::PhotoAlbum.text(s) }]
  end
end
