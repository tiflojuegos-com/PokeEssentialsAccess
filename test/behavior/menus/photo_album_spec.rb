# The photo album plugin, and the divergence that decides whether it works at all: one copy resolves a
# slot's file through obtener_archivo_captura, the other has no such method and matches the name against
# its own directory listing. Calling the missing method would have reported every photo as an empty slot.
# The harness loads every plugin reader, so this spec does not pull it in itself. It used to, back
# when only the running profile's declared plugins were loaded -- and once the harness started
# loading them all, that require became a SECOND load of the same file: require does not know
# about a file already brought in with eval, so every constant in it was reassigned.

class FakeAlbumWithHelper
  def initialize(files); @files = files; end
  def obtener_archivo_captura(i); @files[i]; end
end

Suite.define("photo album: the slot's file is found by whichever route the plugin offers") do
  pa = PokeAccess::PhotoAlbum

  with = FakeAlbumWithHelper.new(["Fotos/Partida 1/capture000_04_07_2026.png", nil, "Fotos/Partida 1/capture002_09_09_2026.png"])
  [[:@page, 0], [:@photo, 0], [:@numpages, 2], [:@numcapturas, 2]].each { |k, v| with.instance_variable_set(k, v) }
  eq "the copy with the helper uses it", pa.file_for(with, 2), "Fotos/Partida 1/capture002_09_09_2026.png"
  eq "the date comes off the filename", pa.date_of("Fotos/capture002_09_09_2026.png"), "9/9/2026"
  eq "a name with no stamp has no date", pa.date_of("Fotos/capture002.png"), nil

  # The other copy: no helper at all. The listing is seeded here because the real one globs the disk once
  # per scene -- this reader runs every frame and must never scan a directory per frame.
  without = Object.new
  without.instance_variable_set(:@pa_album_files, ["Fotos/capture000_01_02_2026.png", "Fotos/capture001_03_04_2026.png"])
  [[:@page, 0], [:@photo, 1], [:@numpages, 1], [:@numcapturas, 2]].each { |k, v| without.instance_variable_set(k, v) }
  eq "the copy without it matches the listing", pa.file_for(without, 1), "Fotos/capture001_03_04_2026.png"
  eq "and an index nobody saved is an empty slot", pa.file_for(without, 7), nil

  eq "a filled slot is numbered, dated and placed on its page",
     pa.text(without),
     "#{PokeAccess::I18n.t(:alb_photo, :n => 2, :tot => 2)}, 3/4/2026, #{PokeAccess::I18n.t(:alb_page, :n => 1, :tot => 1)}"

  without.instance_variable_set(:@photo, 3)
  eq "an empty slot says so and still says where it is",
     pa.text(without),
     "#{PokeAccess::I18n.t(:alb_empty)}, #{PokeAccess::I18n.t(:alb_page, :n => 1, :tot => 1)}"
end
