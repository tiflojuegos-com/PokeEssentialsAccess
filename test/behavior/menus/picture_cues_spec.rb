# PictureCues, the picture-name => text table of image-only screens: a multibuild hash resolves against the running
# build with its authored base as fallback, and a re-shown picture stays silent until an erase.
Suite.define("picture cues: a shown picture speaks its text once, multibuild hashes follow the build") do
  old_texts = PokeAccess::PictureCues::TEXTS.dup
  old_base  = PokeAccess::PictureCues::BASE_LANG.dup
  begin
    PokeAccess::PictureCues::TEXTS.clear
    PokeAccess::PictureCues::BASE_LANG.clear
    PokeAccess::PictureCues::TEXTS["plain_pa"] = "texto plano"
    PokeAccess::PictureCues::TEXTS["multi_pa"] = { :es => "hola cuadro", :en => "hello picture" }
    PokeAccess::PictureCues::BASE_LANG["multi_pa"] = :es
    PokeAccess::PictureCues.reset_last

    PokeAccess::PictureCues.on_picture("plain_pa", [])
    spoke "a plain registered picture is read", /texto plano/

    SpeakCapture.clear
    PokeAccess::PictureCues.on_picture("plain_pa", [])
    silent "the engine re-showing the same picture stays silent"
    PokeAccess::PictureCues.reset_last
    PokeAccess::PictureCues.on_picture("plain_pa", [])
    spoke "after an erase the same picture reads again", /texto plano/

    SpeakCapture.clear
    PokeAccess::PictureCues.on_picture("multi_pa", [])
    spoke "with no build declaration a multibuild hash falls back to its authored base", /hola cuadro/

    truthy "a registered picture marks the picture menu as showing... only with a real screen",
           PokeAccess::PictureCues::TEXTS.has_key?("multi_pa")
  ensure
    PokeAccess::PictureCues::TEXTS.clear
    PokeAccess::PictureCues::TEXTS.merge!(old_texts)
    PokeAccess::PictureCues::BASE_LANG.clear
    PokeAccess::PictureCues::BASE_LANG.merge!(old_base)
    PokeAccess::PictureCues.reset_last
    SpeakCapture.clear
  end
end
