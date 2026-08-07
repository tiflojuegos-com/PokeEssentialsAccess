module PokeAccess
  # Keyboard text entry (naming). With USEKEYBOARDTEXTENTRY the player types on the physical keyboard,
  # so typed/deleted characters are echoed and the mod's global keys are suppressed while a field is active.
  module TextEntry
    # Reads the character at the cursor when it moves without the text changing (pure left/right
    # navigation), so deletions/insertions are not double-read.
    def self.cursor_read(win)
      helper = win.instance_variable_get(:@helper)
      return unless helper
      cur = (helper.cursor rescue nil)
      return if cur.nil?
      txt = (helper.text rescue "")
      len = txt.scan(/./m).length
      lastcur = win.instance_variable_get(:@access_cursor)
      lastlen = win.instance_variable_get(:@access_textlen)
      if !lastcur.nil? && cur != lastcur && len == lastlen
        c = txt.scan(/./m)[cur]
        PokeAccess.speak(c.nil? ? PokeAccess::I18n.t(:te_end) : (c == " " ? PokeAccess::I18n.t(:key_space) : c), true)
      end
      win.instance_variable_set(:@access_cursor, cur)
      win.instance_variable_set(:@access_textlen, len)
    rescue StandardError
      nil
    end
  end
end

# Echo each inserted character (insert is inherited by the keyboard window).
PokeAccess::Hooks.after_hook("Window_TextEntry", :insert) do |_w, _r, args|
  PokeAccess::Keys.typing!
  c = args[0].to_s
  PokeAccess.speak(c == " " ? PokeAccess::I18n.t(:key_space) : c, true) unless c.empty?
end

# Announce deletions.
PokeAccess::Hooks.after_hook("Window_TextEntry", :delete) do |_w, _r, _a|
  PokeAccess::Keys.typing!
  PokeAccess.speak(PokeAccess::I18n.t(:te_deleted), true)
end

# Suppress mod commands while a text field updates (the keyboard subclass overrides update without super).
#
# hook_container because update DRIVES the two hooks above: insert and delete are called from inside it, so
# under the default reentrancy guard both were discarded as nested and neither the typed character nor the
# deletion was ever echoed -- the one thing this file exists to do.
["Window_TextEntry_Keyboard", "Window_TextEntry"].each do |cn|
  PokeAccess::Hooks.after_hook(cn, :update, :hook_container => true) do |win, _r, _a|
    if (win.active rescue true)
      PokeAccess::Keys.typing!
      PokeAccess::TextEntry.cursor_read(win)
    end
  end
end

module PokeAccess
  # Modern cursor-mode naming (PokemonEntryScene2): an on-screen grid plus mode tabs and Back/OK, driven
  # by @cursorpos/@mode with no command window, so the generic reader never sees it. gen-6 uses
  # Window_CharacterEntry (already covered), so this hook simply does not fire there.
  module CursorNaming
    # The mode tabs by layout size. The modern screen has four (upper, lower, accents, symbols); the gen-6
    # one has three and drops the accents tab, which is why the size decides and not a fixed table.
    MODE_KEYS = { 3 => [:nm_upper, :nm_lower, :nm_symbols],
                  4 => [:nm_upper, :nm_lower, :nm_accents, :nm_symbols] }

    # Announces the focused grid character or control on cursor/mode change, and echoes an inserted
    # character or a deletion when the entered text changes.
    def self.poll(scene)
      mode = PokeAccess.ivar_i(scene, :@mode)
      pos = PokeAccess.ivar(scene, :@cursorpos)
      txt = (scene.instance_variable_get(:@helper).text rescue "")
      len = txt.scan(/./m).length
      lastlen = scene.instance_variable_get(:@access_len)
      if !lastlen.nil? && len != lastlen
        c = txt.scan(/./m)[-1].to_s
        say = (len > lastlen) ? (c == " " ? PokeAccess::I18n.t(:key_space) : c) : PokeAccess::I18n.t(:te_deleted)
        PokeAccess.speak(say, true)
      elsif !pos.nil? && (pos != scene.instance_variable_get(:@access_pos) ||
                          mode != scene.instance_variable_get(:@access_mode))
        PokeAccess.speak(focus_text(scene, mode, pos), true)
      end
      scene.instance_variable_set(:@access_pos, pos)
      scene.instance_variable_set(:@access_mode, mode)
      scene.instance_variable_set(:@access_len, len)
    rescue StandardError
      nil
    end

    # The spoken label of the focused element: a control name, or the grid character at the cursor.
    def self.focus_text(scene, mode, pos)
      if pos.to_i < 0
        k = control_key(scene, pos)
        return k ? PokeAccess::I18n.t(k) : ""
      end
      chars = (scene.class.send(:class_variable_get, :@@Characters)[mode][0] rescue nil)
      c = chars ? chars[pos].to_s : ""
      c == " " ? PokeAccess::I18n.t(:key_space) : c
    end

    # The i18n key for a control, from its negative cursor position. BACK and OK are always the last two;
    # the mode tabs sit before them and their COUNT is the divergence -- four in the modern layout at -6..-3,
    # three in the gen-6 one at -5..-3. A table fixed at -6 therefore named every gen-6 tab as the next one
    # along: standing on UPPER the screen said "lowercase". Only awakening reaches this screen among the
    # gen-6 games (the other six force the keyboard entry mode), and there only if the player picks the
    # cursor mode in the options. Counting the game's own @@Characters serves both layouts.
    def self.control_key(scene, pos)
      return :nm_back if pos == -2
      return :nm_ok if pos == -1
      n = (scene.class.send(:class_variable_get, :@@Characters).length rescue 4)
      keys = MODE_KEYS[n]
      return nil unless keys
      i = pos + n + 2
      (i >= 0 && i < n) ? keys[i] : nil
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonEntryScene2", :pbUpdate) do |scene, _r, _a|
  (PokeAccess::Keys.typing! rescue nil)
  PokeAccess::CursorNaming.poll(scene)
end
