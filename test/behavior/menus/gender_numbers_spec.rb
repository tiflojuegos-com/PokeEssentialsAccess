# Opalo's numbered gender portraits (pantallaGenero1/2) are declared by its profile, the other way round from the core
# default; this repo's profile file is evaluated for real, and everything it registers restored.
Suite.define("opalo: the numbered gender portraits are declared, not guessed") do
  cues = PokeAccess::PictureCues
  numbers = PokeAccess::Config.gender_numbers
  texts = cues::TEXTS.dup
  handlers = cues::HANDLERS.length
  begin
    eq "the core default numbers the boy first", PokeAccess::Appearance::GENDER_NUMBERS, { 1 => :ap_boy, 2 => :ap_girl }
    PokeAccess::Config.gender_numbers = {}
    eq "and with no declaration that default is what a game gets",
       [PokeAccess::Appearance.gender_for_picture("pantallaGenero1"),
        PokeAccess::Appearance.gender_for_picture("pantallaGenero2")], [:ap_boy, :ap_girl]

    path = File.join(Harness::ROOT, "games", "opalo", "picture_cues.rb")
    eval(File.read(path), TOPLEVEL_BINDING, path)

    eq "opalo numbers them the other way, which is what its selector really shows",
       [PokeAccess::Appearance.gender_for_picture("pantallaGenero1"),
        PokeAccess::Appearance.gender_for_picture("pantallaGenero2")], [:ap_girl, :ap_boy]
    falsy "the neutral opening portrait belongs to neither",
          PokeAccess::Appearance.gender_for_picture("pantallaGenero0")
    falsy "and a name with no number at all is not a gender portrait",
          PokeAccess::Appearance.gender_for_picture("introEbano1")
  ensure
    PokeAccess::Config.gender_numbers = numbers
    cues::TEXTS.clear
    cues::TEXTS.merge!(texts)
    cues::HANDLERS.slice!(handlers..-1) if cues::HANDLERS.length > handlers
  end
end
