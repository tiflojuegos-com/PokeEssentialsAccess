# The photo album plugin (PhotoAlbum): a slot's file from the copy's own lookup or the album folder's listing, its
# date off the filename, and the focused slot said on the grid with its page, or opened with the date it paints.
class PhotoAlbumTest < PokeAccessTest
  Album = PokeAccess::PhotoAlbum
  PHOTOS = ["Fotos/Partida 1/capture000_04_07_2026.png", "Fotos/Partida 1/capture001_03_04_2026.png", nil,
            "Fotos/Partida 1/capture003_09_09_2026.png", "Fotos/Partida 1/capture004_10_09_2026.png",
            "Fotos/Partida 1/capture005_11_09_2026.png", "Fotos/Partida 1/capture006_25_12_2026.png"].freeze

  # An album scene of the copy that looks its photos up itself (obtener_archivo_captura), by slot.
  class AlbumWithLookup
    def initialize(files, ivars = {})
      @files = files
      ivars.each { |name, value| instance_variable_set(name, value) }
    end

    def obtener_archivo_captura(index); @files[index]; end
  end

  # The same copy with its lookup private.
  class AlbumWithPrivateLookup < AlbumWithLookup
    private :obtener_archivo_captura
  end

  # A copy whose lookup fails.
  class AlbumWithBrokenLookup < AlbumWithLookup
    def obtener_archivo_captura(_index); raise IOError, "the album folder is gone"; end
  end

  test "a copy with its own lookup takes the slot's file from it" do
    assert_equal PHOTOS[3], Album.file_for(AlbumWithLookup.new(PHOTOS), 3)
  end

  test "a lookup the copy keeps private is used too" do
    assert_equal PHOTOS[3], Album.file_for(AlbumWithPrivateLookup.new(PHOTOS), 3)
  end

  test "a slot its lookup leaves empty, or a lookup that fails, has no file" do
    assert_nil Album.file_for(AlbumWithLookup.new(PHOTOS), 2), "an empty slot"
    assert_nil Album.file_for(AlbumWithBrokenLookup.new(PHOTOS), 3), "a failing lookup"
  end

  test "without a lookup, the slot's file comes from the album folder's listing" do
    with_album_folder(["capture000_01_02_2026.png", "capture001_03_04_2026.png", "portada.png"]) do |dir|
      scene = World.stub_scene
      assert_equal File.join(dir, "capture001_03_04_2026.png"), Album.file_for(scene, 1), "a saved slot"
      assert_nil Album.file_for(scene, 7), "a slot nobody saved"
    end
  end

  test "the album folder is listed once per scene" do
    with_album_folder(["capture000_01_02_2026.png"]) do |dir|
      scene = World.stub_scene
      Album.file_for(scene, 0)
      File.write(File.join(dir, "capture001_03_04_2026.png"), "")
      assert_nil Album.file_for(scene, 1), "a photo saved after the listing"
    end
  end

  test "with no album folder declared, the plugin's own Fotos folder is listed" do
    Dir.mktmpdir("pa-album") do |dir|
      Dir.mkdir(File.join(dir, "Fotos"))
      File.write(File.join(dir, "Fotos", "capture000_01_02_2026.png"), "")
      found = Dir.chdir(dir) { Album.file_for(World.stub_scene, 0) }
      assert_equal "Fotos/capture000_01_02_2026.png", found
    end
  end

  test "the date comes off the last three parts of the filename, without leading zeros" do
    { "Fotos/capture002_09_09_2026.png" => "9/9/2026", "Fotos/04_07_2026.png" => "4/7/2026" }.each do |file, date|
      assert_equal date, Album.date_of(file), "for #{file}"
    end
  end

  test "a filename with fewer than three parts has no date" do
    ["Fotos/capture002_2026.png", "Fotos/capture002.png"].each do |file|
      assert_nil Album.date_of(file), "for #{file}"
    end
  end

  test "a filled slot on the grid says its number of all the photos and its page, and no date" do
    assert_equal "#{photo(2, 3)}, #{page(1, 2)}", Album.text(album(0, 1, :@numpages => 2, :@numcapturas => 3))
  end

  test "a slot on a later page counts the photos of the pages before it" do
    assert_equal "#{photo(7, 7)}, #{page(2, 3)}", Album.text(album(1, 2, :@numpages => 3, :@numcapturas => 7))
  end

  test "an album that keeps no page count is one page" do
    assert_equal "#{photo(2, 3)}, #{page(1, 1)}", Album.text(album(0, 1, :@numcapturas => 3))
  end

  test "an opened photo says its number and the date it paints, and no page" do
    scene = album(0, 1, :@numpages => 2, :@numcapturas => 3, :@viendofoto => true)
    assert_equal "#{photo(2, 3)}, 3/4/2026", Album.text(scene)
  end

  test "an empty slot says so and still says where it is" do
    scene = album(0, 2, :@numpages => 2, :@numcapturas => 3)
    assert_equal "#{PokeAccess::I18n.t(:alb_empty)}, #{page(1, 2)}", Album.text(scene)
  end

  test "in brief a slot says its number alone, and an empty one its page by number alone" do
    t = PokeAccess::I18n
    PokeAccess::Config.verbosity = :brief
    { [1, false] => t.t(:alb_photo_bare, :n => 2),
      [2, false] => "#{t.t(:alb_empty)}, #{t.t(:alb_page_bare, :n => 1)}",
      [1, true] => "#{t.t(:alb_photo_bare, :n => 2)}, 3/4/2026",
      [2, true] => t.t(:alb_empty) }.each do |(slot, opened), said|
      scene = album(0, slot, :@numpages => 2, :@numcapturas => 3, :@viendofoto => opened)
      assert_equal said, Album.text(scene), "slot #{slot}, #{opened ? 'opened' : 'on the grid'}"
    end
  end

  test "the album says the focused slot as the cursor moves, queued at the opening, and its date once opened" do
    reader = PokeAccess::PhotoAlbumReader
    scene = album(0, 0, :@numpages => 2, :@numcapturas => 3)
    reader.watch(scene)
    reader.poll
    reader.poll
    scene.instance_variable_set(:@photo, 1)
    reader.poll
    scene.instance_variable_set(:@viendofoto, true)
    reader.poll
    assert_equal [["#{photo(1, 3)}, #{page(1, 2)}", false], ["#{photo(2, 3)}, #{page(1, 2)}", true],
                  ["#{photo(2, 3)}, 3/4/2026", true]], SpeakCapture.log
  ensure
    reader.unwatch
  end

  private

  # An album of PHOTOS, its cursor on page and photo, with more of the scene's ivars.
  def album(page, photo, ivars = {})
    AlbumWithLookup.new(PHOTOS, { :@page => page, :@photo => photo }.merge(ivars))
  end

  # "Photo n of tot", as the slot says it.
  def photo(n, tot)
    PokeAccess::I18n.t(:alb_photo, :n => n, :tot => tot)
  end

  # "page n of tot", as the slot says it.
  def page(n, tot)
    PokeAccess::I18n.t(:alb_page, :n => n, :tot => tot)
  end

  # Runs the block with the plugin's album folder (ALBUM_DIR) a fresh temporary folder holding the named empty files,
  # yielding the folder; the constant is put back as it was after.
  def with_album_folder(names)
    had = Object.const_defined?(:ALBUM_DIR)
    was = had ? Object.const_get(:ALBUM_DIR) : nil
    Dir.mktmpdir("pa-album") do |dir|
      names.each { |n| File.write(File.join(dir, n), "") }
      Object.send(:remove_const, :ALBUM_DIR) if had
      Object.const_set(:ALBUM_DIR, dir)
      begin
        yield dir
      ensure
        Object.send(:remove_const, :ALBUM_DIR)
        Object.const_set(:ALBUM_DIR, was) if had
      end
    end
  end
end
