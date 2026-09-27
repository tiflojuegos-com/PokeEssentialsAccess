# The photo album plugin: a slot's file comes from obtener_archivo_captura where the copy has it, else from the
# directory listing; the grid says the page it paints, an opened photo the date it paints. Not required here: the
# harness loads it, and a second load reassigns its constants.

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

  without = Object.new
  without.instance_variable_set(:@pa_album_files, ["Fotos/capture000_01_02_2026.png", "Fotos/capture001_03_04_2026.png"])
  [[:@page, 0], [:@photo, 1], [:@numpages, 1], [:@numcapturas, 2]].each { |k, v| without.instance_variable_set(k, v) }
  eq "the copy without it matches the listing", pa.file_for(without, 1), "Fotos/capture001_03_04_2026.png"
  eq "and an index nobody saved is an empty slot", pa.file_for(without, 7), nil

  eq "a filled slot on the grid is numbered and placed on its page, which the grid paints, with no date",
     pa.text(without),
     "#{PokeAccess::I18n.t(:alb_photo, :n => 2, :tot => 2)}, #{PokeAccess::I18n.t(:alb_page, :n => 1, :tot => 1)}"
  without.instance_variable_set(:@viendofoto, true)
  eq "opened, it says the date the photo paints, and no page, which it does not",
     pa.text(without), "#{PokeAccess::I18n.t(:alb_photo, :n => 2, :tot => 2)}, 3/4/2026"
  without.instance_variable_set(:@viendofoto, false)

  without.instance_variable_set(:@photo, 3)
  eq "an empty slot says so and still says where it is",
     pa.text(without),
     "#{PokeAccess::I18n.t(:alb_empty)}, #{PokeAccess::I18n.t(:alb_page, :n => 1, :tot => 1)}"

  PokeAccess::Config.verbosity = :brief
  eq "brief: an empty slot says so, and its page by number alone", pa.text(without),
     "#{PokeAccess::I18n.t(:alb_empty)}, #{PokeAccess::I18n.t(:alb_page_bare, :n => 1)}"
  without.instance_variable_set(:@photo, 1)
  eq "and a filled one its number alone, without the totals", pa.text(without),
     PokeAccess::I18n.t(:alb_photo_bare, :n => 2)
  without.instance_variable_set(:@viendofoto, true)
  eq "opened, its number and date", pa.text(without), "#{PokeAccess::I18n.t(:alb_photo_bare, :n => 2)}, 3/4/2026"
  PokeAccess::Config.verbosity = :full
end
