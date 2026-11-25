# The stock title screens (IntroEventScene), all pictures: the shared title prompt is said when the title opens.
module PokeAccess
  # The title screens' prompt: the screen's name and, while key hints are said, the key that starts the game (the
  # confirm key as remapped, else the game's indicated key); and splash images by a profile's transcription.
  module TitleScreen
    # param screen the key of the screen's spoken name, for another picture that waits for the key (Royal's creator)
    # param default_key the translation key for the game's indicated confirm key
    def self.prompt(screen = :title_screen, default_key = :key_enter)
      PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(screen), hint(default_key))
    end

    # The hint alone, for any screen that waits for the confirm key to go on.
    def self.hint(default_key = :key_enter)
      PokeAccess::I18n.t(:title_press, :key => PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(default_key)))
    end

    # Speaks, queued, the transcription a profile registers (picture_texts) for each splash image shown before the
    # title; an image with none stays silent.
    def self.splash(pics)
      (pics || []).each do |name|
        t = PokeAccess::PictureCues.text_for(name)
        PokeAccess.speak(t, false) if t
      end
    end
  end
end

PokeAccess::Hooks.after_hook("IntroEventScene", :open_title_screen, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, true)
end
