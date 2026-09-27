module PokeAccess
  # Keyboard text entry (naming). With USEKEYBOARDTEXTENTRY the player types on the physical keyboard,
  # so typed/deleted characters are echoed and the mod's global keys are suppressed while a field is active.
  module TextEntry
    # Runs a naming screen with Input.text_input on (modern mkxp-z starts it off and gen-6 scripts never set it),
    # restoring it afterwards; a runtime without the switch is left alone.
    def self.with_keyboard_input
      return yield unless Input.respond_to?(:text_input=)
      was = (Input.respond_to?(:text_input) ? Input.text_input : false) rescue false
      Input.text_input = true unless was
      begin
        yield
      ensure
        Input.text_input = false unless was
      end
    end

    # Speaks the character under a moved cursor while the text length is unchanged (plain left/right navigation).
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

    # Speaks a keyboard naming screen's opening around its opener: the caption from its arguments, then the text it
    # paints (hint sentences gated), minus the question or sign a build also paints.
    # param args the opener's (helptext, minlength, maxlength, initialText, subject, pokemon)
    def self.opening(args)
      PokeAccess.speak(PokeAccess::CursorNaming.caption(args[0], args[3], args[4], args[5]), false)
      PokeAccess::PaintCapture.arm(:entry_caption)
      begin
        yield
      ensure
        q = PokeAccess.clean(args[0].to_s)
        sign = args[4].to_i == 2 ? PokeAccess.clean(PokeAccess::Party.gender_glyph(args[5]).to_s) : nil
        rows = (PokeAccess::PaintCapture.take(:entry_caption) || []).reject do |r|
          c = PokeAccess.clean(r.to_s)
          c == q || (sign && !sign.empty? && c == sign)
        end
        t = PokeAccess::KeyHints.gate_sentences(PokeAccess::PaintCapture.text(rows))
        PokeAccess.speak(t, false) unless t.to_s.strip.empty?
      end
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

# Suppresses mod commands while a text field updates (the keyboard subclass overrides update without super). A
# container: update calls insert and delete, whose hooks would be dropped as nested under a guard.
["Window_TextEntry_Keyboard", "Window_TextEntry"].each do |cn|
  PokeAccess::Hooks.after_hook(cn, :update, :hook_container => true) do |win, _r, _a|
    if (win.active rescue true)
      PokeAccess::Keys.typing!
      PokeAccess::TextEntry.cursor_read(win)
    end
  end
end

module PokeAccess
  # Cursor-mode naming (PokemonEntryScene2): a character grid with mode tabs and Back/OK, driven by @cursorpos and
  # @mode with no command window.
  module CursorNaming
    # The mode tabs by layout size: four in the modern layout, three (no accents) in the gen-6 one.
    MODE_KEYS = { 3 => [:nm_upper, :nm_lower, :nm_symbols],
                  4 => [:nm_upper, :nm_lower, :nm_accents, :nm_symbols] }

    # Speaks the focused character or control on a cursor or mode change, and echoes an insert or delete, then any
    # cursor move it caused (onto OK when the name is full); a tab changed under the cursor is named first.
    def self.poll(scene)
      mode = PokeAccess.ivar_i(scene, :@mode)
      pos = PokeAccess.ivar(scene, :@cursorpos)
      txt = (scene.instance_variable_get(:@helper).text rescue "")
      len = txt.scan(/./m).length
      lastlen = scene.instance_variable_get(:@access_len)
      lastpos = scene.instance_variable_get(:@access_pos)
      lastmode = scene.instance_variable_get(:@access_mode)
      if !lastlen.nil? && len != lastlen
        c = txt.scan(/./m)[-1].to_s
        say = (len > lastlen) ? (c == " " ? PokeAccess::I18n.t(:key_space) : c) : PokeAccess::I18n.t(:te_deleted)
        PokeAccess.speak(say, true)
        tab = (lastmode.nil? || mode == lastmode) ? nil : mode_key(scene, mode)
        if tab && !pos.nil?
          PokeAccess.speak("#{PokeAccess::I18n.t(tab)}. #{focus_text(scene, mode, pos)}", false)
        elsif !pos.nil? && pos != lastpos
          PokeAccess.speak(focus_text(scene, mode, pos), false)
        end
      elsif !pos.nil? && (pos != lastpos || mode != lastmode)
        t = focus_text(scene, mode, pos)
        tab = (lastpos.nil? || mode == lastmode || pos < 0) ? nil : mode_key(scene, mode)
        PokeAccess.speak(tab ? "#{PokeAccess::I18n.t(tab)}. #{t}" : t, !lastpos.nil?)
      end
      scene.instance_variable_set(:@access_pos, pos)
      scene.instance_variable_set(:@access_mode, mode)
      scene.instance_variable_set(:@access_len, len)
    rescue StandardError
      nil
    end

    # The screen's opening line from pbStartScene's arguments: its help text, a Pokemon's sex sign and the box's
    # starting text, labelled as such.
    # param subject the screen's subject kind (2 is a Pokemon)
    def self.caption(helptext, initial, subject, pokemon)
      parts = [PokeAccess.clean(helptext.to_s)]
      parts.push(PokeAccess::Party.gender_glyph(pokemon).to_s) if subject.to_i == 2
      parts.push(PokeAccess::I18n.t(:nm_current, :t => initial.to_s)) unless initial.to_s.strip.empty?
      parts.reject { |p| p.strip.empty? }.join(" ")
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

    # The i18n key of a character tab by its mode number, from the tabs this layout has; nil past them.
    def self.mode_key(scene, mode)
      n = (scene.class.send(:class_variable_get, :@@Characters).length rescue 4)
      keys = MODE_KEYS[n]
      keys ? keys[mode.to_i] : nil
    end

    # The i18n key for a control by its negative cursor position: -2 Back, -1 OK, and before them the tabs, counted
    # from the game's @@Characters (-6..-3 for four, -5..-3 for three).
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

# The whole naming screen runs inside PokemonEntry#pbStartScreen, so the keyboard switch wraps it there; not
# guarded, since the hooks it drives must fire.
PokeAccess::Hooks.around_hook("PokemonEntry", :pbStartScreen, :optional => true) do |_s, nxt, _a|
  PokeAccess::TextEntry.with_keyboard_input { nxt.call }
end

# The keyboard screen's opening caption and painted text (TextEntry.opening).
PokeAccess::Hooks.around_hook("PokemonEntryScene", :pbStartScene, :optional => true) do |_s, nxt, args|
  PokeAccess::TextEntry.opening(args) { nxt.call }
end
PokeAccess::Hooks.around_hook("PokemonEntryScene2", :pbStartScene, :optional => true) do |_scene, nxt, args|
  PokeAccess.speak(PokeAccess::CursorNaming.caption(args[0], args[3], args[4], args[5]), false)
  nxt.call
end
