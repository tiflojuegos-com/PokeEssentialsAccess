# Numbered gender portraits (pantallaGenero1/2). The core table is a GUESS -- one game numbers the boy 1,
# the next numbers the girl 1 -- and a guess that lands the wrong way announces the player as the opposite
# of what is on screen, which is worse than saying nothing. Opalo is the one game that ships them and it
# numbers them the other way round, so its profile declares the mapping; this pins that it does, because
# the failure it prevents is silent and reads as correct.
#
# Driven through the REAL profile file, evaluated the way the harness loads one, and everything it touches
# is restored: it registers picture texts and an observer besides the mapping.
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
    # eval is the harness's own loading mechanism (test/support/harness.rb): this repo's file, by absolute path.
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
