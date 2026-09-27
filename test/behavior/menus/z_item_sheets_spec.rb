# Pokemon Z's sheet items (games/pokemon_z/picture_cues.rb) through ItemHandlers.triggerUseFromBag.

# The bag's item handlers. Other specs give that name to their own handlers inside their suites, so this one bears it
# only while the profile file is evaluated once more over it.
module ZSheetHandlers
  def self.triggerUseFromBag(_item)
    1
  end
end

unless Object.const_defined?(:ItemHandlers)
  Object.const_set(:ItemHandlers, ZSheetHandlers)
  verbose = $VERBOSE
  begin
    $VERBOSE = nil
    load File.join(Harness::ROOT, "games", "pokemon_z", "picture_cues.rb")
  ensure
    $VERBOSE = verbose
    Object.send(:remove_const, :ItemHandlers)
  end
end

# The controls guide and the two Nuzlocke diplomas show a bare sprite on use from the bag, read by their picture's
# transcription for the running build, on every use; the intro shows the controls guide as a picture, read the same.
Suite.define("z item sheets: the controls guide and the diplomas read their sheet on every use") do
  controls = "Controles. Flechas: Movimiento. X: Interactuar / Menú. C: Interactuar / Correr. Z: Atrás. Q: Turbo."
  made = []
  begin
    { :CONTROLES => 700, :DIPLOMANUZ1 => 701, :DIPLOMANUZ2 => 702 }.each do |sym, id|
      next if PBItems.const_defined?(sym)
      PBItems.const_set(sym, id)
      made.push(sym)
    end
    PokeAccess::PictureCues.reset_last
    SpeakCapture.clear
    eq "the bag's handler still answers as the game's", ZSheetHandlers.triggerUseFromBag(700), 1
    eq "the controls guide: its sheet as the Spanish build paints it", SpeakCapture.lines, [controls]
    SpeakCapture.clear
    ZSheetHandlers.triggerUseFromBag(700)
    eq "used again, read again", SpeakCapture.lines, [controls]

    SpeakCapture.clear
    ZSheetHandlers.triggerUseFromBag(702)
    match "the heroic diploma", SpeakCapture.last, /dificultad heroica/
    SpeakCapture.clear
    ZSheetHandlers.triggerUseFromBag(701)
    match "the other diploma", SpeakCapture.last, /nuzlocke de Pokémon Z\. ¡Enhorabuena!/

    SpeakCapture.clear
    ZSheetHandlers.triggerUseFromBag(1)
    silent "any other item says nothing"

    PokeAccess::PictureCues.reset_last
    SpeakCapture.clear
    PokeAccess::PictureCues.on_picture("helpbg", [1, "helpbg"])
    eq "the intro's first picture is the same sheet", SpeakCapture.lines, [controls]
  ensure
    made.each { |sym| PBItems.send(:remove_const, sym) }
    PokeAccess::PictureCues.reset_last
  end
end
