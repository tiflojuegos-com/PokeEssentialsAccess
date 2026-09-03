module PokeAccess
  # Picture-based screens with no readable text. Games register picture-name => text in TEXTS (read when
  # shown), and/or observer procs via register (for screens whose selection is not a single highlighted
  # picture). Skips the immediate duplicate the engine may re-show.
  #
  # A value may instead be a hash of build language => transcription, for a game shipped as several
  # per-language builds that paint different words into the same picture file; GameLang picks the one the
  # running build shows. These are TRANSCRIPTIONS of what is on screen, not mod prose, so they follow the
  # build and never the reader's language setting.
  module PictureCues
    TEXTS = {}
    HANDLERS = []
    # The language each game's picture strings were authored in, by profile, for the fallback when a build
    # declares a language nobody transcribed.
    BASE_LANG = {}

    # Registers an observer called as (name, show_args) on every picture shown.
    def self.register(&blk); HANDLERS.push(blk); end

    # True when a registered picture screen is on screen (a picture-based menu like the difficulty/
    # nuzlocke selectors or the alchemy book). These run outside the normal menu/interpreter state, so
    # busy? cannot detect them; checking for any shown picture whose name is registered is game-neutral.
    def self.menu_showing?
      return false if TEXTS.empty?
      return false unless defined?($game_screen) && $game_screen
      pics = ($game_screen.pictures rescue nil)
      return false unless pics
      (1..50).any? do |i|
        nm = (pics[i].name rescue nil)
        nm && !nm.to_s.empty? && TEXTS.has_key?(nm.to_s)
      end
    rescue StandardError
      false
    end

    # Narrates a registered picture and notifies observers.
    def self.on_picture(name, args)
      n = name.to_s
      t = TEXTS[n]
      if t && n != @last
        @last = n
        t = PokeAccess::GameLang.pick(t, BASE_LANG[n] || :es) if t.is_a?(Hash)
        PokeAccess.speak(PokeAccess::I18n.t(t), true) if t
      end
      HANDLERS.each { |h| (h.call(n, args) rescue nil) }
    end

    # Clears the dedup so a re-shown picture speaks again (called when one is erased), so a reference
    # card opened repeatedly (e.g. the berry chart) is read every time.
    def self.reset_last; @last = nil; end
  end
end

PokeAccess::Hooks.after_hook("Game_Picture", :show) do |_p, _r, args|
  PokeAccess::PictureCues.on_picture(args[0], args)
end

# A picture being erased ends its narration context, so re-showing the same picture reads it again.
PokeAccess::Hooks.after_hook("Game_Picture", :erase) do |_p, _r, _a|
  PokeAccess::PictureCues.reset_last
end

# New-game character selection reads its gender from the shown boy/girl portrait, via the single picture
# hook (Appearance gates it to the selection, before $Trainer exists).
PokeAccess::PictureCues.register do |name, _args|
  (PokeAccess::Appearance.on_picture(name) rescue nil) if defined?(PokeAccess::Appearance)
end
