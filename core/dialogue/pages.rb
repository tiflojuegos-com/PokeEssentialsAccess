module PokeAccess
  # Dialogue read page by page as the message window pauses (the dialogue_pages option), each page cutting off the
  # last; polled per frame, not hooked, so it also reads under the reentrancy guard. A message it cannot follow, or
  # whose pages went unheard, is said whole.
  module DialoguePages
    # Takes over a message about to be shown in win, when the option is on and the window is one whose
    # pages can be followed. Returns false to leave it to the whole-message reading.
    def self.open(win, message, letterbyletter)
      return false unless (PokeAccess::Config.dialogue_pages rescue false)
      return false if letterbyletter == false || PokeAccess.message_depth > 0
      return false unless win.respond_to?(:pausing?) && PokeAccess.ivar(win, :@textchars).is_a?(Array)
      t = PokeAccess.clean(message)
      @skip = PokeAccess.recently_said?(t)
      PokeAccess.note_dialogue_seen
      @head = @skip ? nil : PokeAccess.take_head
      PokeAccess.say_dialogue_skip(message, @head)
      @win = win
      @chars = PokeAccess.ivar(win, :@textchars)
      @said = 0
      @heard = false
      @text = t
      true
    rescue StandardError
      false
    end

    # Once a frame: when the window stands at a page break or has drawn the whole message, says what it
    # drew since the last time. A new message's characters are a new array, which starts the count over.
    def self.poll
      w = @win
      return if w.nil?
      chars = PokeAccess.ivar(w, :@textchars)
      return unless chars.is_a?(Array)
      unless chars.equal?(@chars)
        @chars = chars
        @said = 0
      end
      flush(w, chars) if (w.pausing? rescue false) || !(w.busy? rescue true)
    rescue StandardError
      nil
    end

    # Speaks the characters drawn since the last page, interrupting, filed as dialogue (or battle); the first page
    # heard carries the message's head.
    def self.flush(w, chars)
      cur = [PokeAccess.ivar_i(w, :@curchar), chars.length].min
      return if cur <= @said
      text = PokeAccess.clean(chars[@said...cur].join)
      @said = cur
      return if @skip || text.strip.empty?
      text = PokeAccess.led(@head, text) unless @heard
      @heard = true
      PokeAccess.speak(text, true, PokeAccess.dialogue_category)
    end

    # The message closed: the rest of it, the whole of it (with its head) if no page was ever heard, and the line
    # promised for after it.
    def self.close(win)
      return unless @win && win.equal?(@win)
      chars = PokeAccess.ivar(win, :@textchars)
      flush(win, chars) if chars.is_a?(Array) && chars.equal?(@chars)
      kind = PokeAccess.dialogue_category
      PokeAccess.speak(PokeAccess.led(@head, @text), false, kind) unless @heard || @skip
      tail = PokeAccess.take_tail
      PokeAccess.speak(tail, false, kind) if tail
      @win = nil
    rescue StandardError
      @win = nil
    end
  end
end

PokeAccess::Keys.on_frame { PokeAccess::DialoguePages.poll }
