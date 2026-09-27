module PokeAccess
  # Uranium's language picker (LanguageSelection, from Options or the first boot): its painted title and the focused
  # language name, then the painted question with its two picture buttons, X to decline and O to accept.
  module UraniumLanguage
    # Runs drawSelection keeping what it paints, then says its title and the focused language, queued.
    def self.opening(ls)
      pairs = []
      begin
        @opening = true
        pairs = PokeAccess::PaintCapture.sample { yield }
      ensure
        @opening = false
      end
      title = pairs.first ? PokeAccess.clean(pairs.first[0].to_s) : ""
      PokeAccess.speak(title, false) unless title.empty?
      PokeAccess::Cursor.reset(ls, :ura_lang)
      focus(ls, false)
    end

    # Says the focused language once per change, by the name the list paints; quiet while drawSelection runs.
    def self.focus(ls, interrupt = true)
      return if @opening
      PokeAccess::Cursor.announce(ls, :ura_lang, PokeAccess.ivar(ls, :@selection), interrupt) { ls.languageName }
    end

    # Runs the confirmation loop; back on the list its focused language is said again.
    def self.confirming(ls)
      PokeAccess::Cursor.reset(ls, :ura_lang_ok)
      yield
    ensure
      PokeAccess::Cursor.reset(ls, :ura_lang)
    end

    # Runs a drawConfirm and says the focused button when it changes, after the painted question on the first draw.
    def self.confirm_drawn(ls)
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      accept = PokeAccess.ivar(ls, :@accept) ? 1 : 0
      first = PokeAccess::Cursor.current(ls, :ura_lang_ok).nil?
      if PokeAccess::Cursor.changed?(ls, :ura_lang_ok, accept)
        button = PokeAccess::I18n.t(accept == 1 ? :ura_lang_yes : :ura_lang_no)
        question = pairs.first ? PokeAccess.clean(pairs.first[0].to_s) : ""
        PokeAccess.speak((first && !question.empty?) ? "#{question} #{button}" : button, true)
      end
      ret
    end
  end
end

PokeAccess::Game.define("uranium") do
  around("LanguageSelection", :drawSelection) { |ls, nxt, _a| PokeAccess::UraniumLanguage.opening(ls) { nxt.call } }
  after("LanguageSelection", :update, :hook_container => true) { |ls, _r, _a| PokeAccess::UraniumLanguage.focus(ls) }
  around("LanguageSelection", :confirm) { |ls, nxt, _a| PokeAccess::UraniumLanguage.confirming(ls) { nxt.call } }
  around("LanguageSelection", :drawConfirm) { |ls, nxt, _a| PokeAccess::UraniumLanguage.confirm_drawn(ls) { nxt.call } }
end
