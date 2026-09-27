module PokeAccess
  # Picture-based screens with no readable text: games register picture name => text in TEXTS (read when shown,
  # skipping an immediate re-show) or observers via register. A text may be a {build language => transcription}
  # hash, picked by the running build (GameLang), never the reader's language.
  module PictureCues
    TEXTS = {}
    HANDLERS = []
    # Picture name => the language its profile authored it in; the fallback for an untranscribed build language.
    BASE_LANG = {}

    # Registers an observer called as (name, show_args) on every picture shown.
    def self.register(&blk); HANDLERS.push(blk); end

    # True while any shown picture (slots 1-50) is a registered one: a picture menu busy? cannot detect.
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

    # The text registered for a picture name, a build's transcription picked from a Hash; nil when there is none.
    def self.text_for(name)
      n = name.to_s
      t = TEXTS[n]
      t = PokeAccess::GameLang.pick(t, BASE_LANG[n] || :es) if t.is_a?(Hash)
      t ? PokeAccess::I18n.t(t) : nil
    end

    # Narrates a registered picture and notifies observers.
    def self.on_picture(name, args)
      n = name.to_s
      if TEXTS[n] && n != @last
        @last = n
        t = text_for(n)
        PokeAccess.speak(t, true) if t
      end
      HANDLERS.each { |h| (h.call(n, args) rescue nil) }
    end

    # Clears the dedup, so a picture shown again after an erase speaks again.
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

# The new-game character selection's portrait gender (Appearance gates it to the selection).
PokeAccess::PictureCues.register do |name, _args|
  (PokeAccess::Appearance.on_picture(name) rescue nil) if defined?(PokeAccess::Appearance)
end
