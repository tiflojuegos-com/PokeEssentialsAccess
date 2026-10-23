module PokeAccess
  # Game-window focus: GetAsyncKeyState reads keys even in the background, so mod keys are gated on the game being
  # the foreground window. Fail-safe: when focus cannot be read, the answer is "focused".
  module Focus
    GFW   = (Win32API.new("user32", "GetForegroundWindow", "", "l") rescue nil)
    GAW   = (Win32API.new("user32", "GetActiveWindow", "", "l") rescue nil)
    GCPID = (Win32API.new("kernel32", "GetCurrentProcessId", "", "l") rescue nil)
    GWTPID = (Win32API.new("user32", "GetWindowThreadProcessId", "lp", "l") rescue nil)
    @game_hwnd = nil

    # The remembered game-window handle, or nil while none has been recorded yet (for diagnostics).
    def self.hwnd; @game_hwnd; end

    # Records the window in front as the game's on a step (player movement mostly happens focused), so focused? stays
    # correct even after a fullscreen toggle recreates the window; never another program's (own?), in front while the
    # engine walks the player on by itself (an ice slide).
    def self.mark_focused
      return unless GFW
      h = (GFW.call rescue 0)
      @game_hwnd = h if h && h != 0 && own?(h) != false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True while the game window is foreground: the window in front is this process's; where its owner cannot be told,
    # it is the one first seen in front (or marked); true when focus is unreadable.
    def self.focused?
      return true unless GFW
      fg = (GFW.call rescue nil)
      return true if fg.nil?
      mine = own?(fg)
      @game_hwnd = fg if mine
      return mine unless mine.nil?
      @game_hwnd = fg if @game_hwnd.nil? && fg != 0
      return true if @game_hwnd.nil?
      fg == @game_hwnd
    rescue StandardError => e
      PokeAccess.swallowed(e)
      true
    end

    # Whether window h is this process's, or nil where its owner cannot be told: no window, no such call, or an engine
    # that fakes the handle and leaves the owner unwritten.
    def self.own?(h)
      return nil unless GWTPID && GCPID && h != 0
      buf = [0].pack("L")
      return nil if GWTPID.call(h, buf) == 0
      pid = buf.unpack("L")[0]
      pid == 0 ? nil : pid == GCPID.call
    end
  end
end
