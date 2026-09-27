# Photo album ("Fotos del equipo", AlbumFotos_Scene): pages of a 2x2 screenshot grid (@photo 0-3, @page) polled
# during pbUpdateAlbum; each slot's number and date come from its filename, capture###_dd_mm_yyyy.png.
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

    # The file behind a slot, via obtener_archivo_captura (a raise there is logged) or a glob; nil if empty.
    def self.file_for(scene, index)
      if scene.respond_to?(:obtener_archivo_captura, true)
        return (scene.send(:obtener_archivo_captura, index) rescue (PokeAccess.log_once("album_lookup", $!); nil))
      end
      tag = sprintf("capture%03d", index)
      files(scene).find { |f| f.include?(tag) }
    end

    # The date a capture filename ends with, or nil. Read through to_i because the filename pads to two
    # digits and the screen prints the bare number.
    def self.date_of(file)
      parts = File.basename(file.to_s, ".png").split("_")
      return nil if parts.length < 3
      "#{parts[-3].to_i}/#{parts[-2].to_i}/#{parts[-1].to_i}"
    end

    # What the focused slot is, as a numbered photo or an empty slot: on the grid with its page, which the grid
    # paints; opened, with the date, which only the opened photo paints.
    def self.text(scene)
      page  = PokeAccess.ivar_i(scene, :@page)
      photo = PokeAccess.ivar_i(scene, :@photo)
      pages = (PokeAccess.ivar(scene, :@numpages) || 1).to_i
      index = page * 4 + photo
      file  = file_for(scene, index)
      viewing = PokeAccess.ivar(scene, :@viendofoto) ? true : false
      pos = PokeAccess::Verbosity.keep?(:positions, :medium)
      head = if file
               d = viewing ? date_of(file) : nil
               t = if pos
                     PokeAccess::I18n.t(:alb_photo, :n => index + 1, :tot => PokeAccess.ivar_i(scene, :@numcapturas))
                   else
                     PokeAccess::I18n.t(:alb_photo_bare, :n => index + 1)
                   end
               d ? "#{t}, #{d}" : t
             else
               PokeAccess::I18n.t(:alb_empty)
             end
      return head if viewing
      return "#{head}, #{PokeAccess::I18n.t(:alb_page, :n => page + 1, :tot => pages)}" if pos
      file ? head : "#{head}, #{PokeAccess::I18n.t(:alb_page_bare, :n => page + 1)}"
    end
  end

  PhotoAlbumReader = SceneWatcher.reader("AlbumFotos_Scene", :pbUpdateAlbum, :photo_album, :optional => true) do |s|
    viewing = (s.instance_variable_get(:@viendofoto) rescue false)
    [[PokeAccess.ivar_i(s, :@page), PokeAccess.ivar_i(s, :@photo), viewing],
     lambda { PokeAccess::PhotoAlbum.text(s) }]
  end
end
