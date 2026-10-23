module PokeAccess
  # PokéLiberty's Unown notebook (BlocUnownScene): a grid of the Unown forms seen, one per letter of UNOWN_SHAPE, and
  # a word written with them, kept in a game variable and drawn as Unown icons; the letter under the cursor and the
  # word as it changes are said, since the screen shows neither as text.
  module BlocUnown
    # Characters a screen reader would drop, said by name.
    MARKS = { "?" => :unown_question, "!" => :unown_exclaim }

    # The character at a grid index, or nil outside UNOWN_SHAPE.
    def self.char_at(idx)
      shape = PokeAccess.const_at("UNOWN_SHAPE")
      return nil unless shape && idx.is_a?(Integer) && idx >= 0 && idx < shape.length
      shape[idx, 1]
    end

    # A character as spoken: a letter as itself, the two marks by name.
    def self.say_char(ch)
      MARKS[ch] ? PokeAccess::I18n.t(MARKS[ch]) : ch
    end

    # The word as the game keeps it (the variable the scene writes), "" when it holds none.
    def self.word
      var = PokeAccess.const_at("UNOWN_WORD_VARIABLE")
      w = var ? ($game_variables[var] rescue nil) : nil
      w.is_a?(String) ? w : ""
    end

    # The word as spoken, each mark by name, or that it is empty.
    def self.word_text(w)
      return PokeAccess::I18n.t(:unown_word_empty) if w.empty?
      PokeAccess::I18n.t(:unown_word, :word => w.gsub(/[?!]/) { |m| " #{say_char(m)} " }.squeeze(" ").strip)
    end

    # The cell under the cursor: its letter, or that its form is still unseen (the grid leaves that cell blank).
    def self.cell_text(scene, idx)
      ch = char_at(idx)
      return nil unless ch
      seen = PokeAccess.sprite(scene, "form#{idx}")
      seen ? say_char(ch) : PokeAccess::I18n.t(:unown_unseen, :letter => say_char(ch))
    end

    # Says the cell the cursor moved to; the first, on opening, queued with the word and, with hints, the keys.
    def self.moved(scene)
      idx = PokeAccess.ivar(scene, :@selIdx)
      opening = !PokeAccess.ivar(scene, :@access_unown_open)
      return unless PokeAccess::Cursor.changed?(scene, :unown_cell, idx)
      t = cell_text(scene, idx)
      return unless t
      if opening
        scene.instance_variable_set(:@access_unown_open, true)
        hint = PokeAccess::I18n.t(:unown_hint, :key => PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter)))
        t = PokeAccess::Verbosity.with_hint(PokeAccess.sentences([t, word_text(word)]), hint)
      end
      PokeAccess.speak(t, !opening)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says the word after a key changed it (added a letter, erased one or cleared it), and nothing when it did not.
    def self.edited(scene, before)
      w = word
      return if w == before || PokeAccess.ivar(scene, :@ommitLetter)
      PokeAccess.speak(word_text(w), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("BlocUnownScene", :moveCursor, :optional => true) do |scene, _r, _a|
  PokeAccess::BlocUnown.moved(scene)
end

# The three edits, each said as the word it leaves; clearWord asks first with a standard confirmation.
PokeAccess::Hooks.around_hook("BlocUnownScene", :addLetter, :optional => true) do |scene, nxt, _a|
  before = PokeAccess::BlocUnown.word
  r = nxt.call
  PokeAccess::BlocUnown.edited(scene, before)
  r
end
PokeAccess::Hooks.around_hook("BlocUnownScene", :backspace, :optional => true) do |scene, nxt, _a|
  before = PokeAccess::BlocUnown.word
  r = nxt.call
  PokeAccess::BlocUnown.edited(scene, before)
  r
end
PokeAccess::Hooks.around_hook("BlocUnownScene", :clearWord, :optional => true,
                              :hook_container => true) do |scene, nxt, _a|
  before = PokeAccess::BlocUnown.word
  r = nxt.call
  PokeAccess::BlocUnown.edited(scene, before)
  r
end
