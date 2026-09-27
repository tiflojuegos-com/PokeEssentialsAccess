module PokeAccess
  # Game-window focus: GetAsyncKeyState reads keys even in the background, so mod keys are gated on the game being
  # the foreground window. Fail-safe: when focus cannot be read, the answer is "focused".
  module Focus
    GFW   = (Win32API.new("user32", "GetForegroundWindow", "", "l") rescue nil)
    GAW   = (Win32API.new("user32", "GetActiveWindow", "", "l") rescue nil)
    GCPID = (Win32API.new("kernel32", "GetCurrentProcessId", "", "l") rescue nil)
    @game_hwnd = nil

    # The remembered game-window handle, or nil while none has been recorded yet (for diagnostics).
    def self.hwnd; @game_hwnd; end

    # Records the game window handle while focused (player movement only happens focused), so focused?
    # stays correct even after a fullscreen toggle recreates the window.
    def self.mark_focused
      return unless GFW
      h = (GFW.call rescue 0)
      @game_hwnd = h if h && h != 0
    rescue StandardError
      nil
    end

    # True while the game window is foreground, or when focus is unreadable.
    def self.focused?
      return true unless GFW
      fg = (GFW.call rescue nil)
      return true if fg.nil?
      @game_hwnd = fg if @game_hwnd.nil? && fg != 0
      return true if @game_hwnd.nil?
      fg == @game_hwnd
    rescue StandardError
      true
    end
  end
end
