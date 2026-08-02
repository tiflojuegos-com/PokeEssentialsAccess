module PokeAccess
  # Game-window focus, and nothing else. GetAsyncKeyState reads the keyboard even while the game sits in
  # the background, so every mod key has to be gated on "is the game the foreground window": that question,
  # and the window handle it needs, live here.
  #
  # Fail-safe by design: whenever focus cannot be read the answer is "focused". A mod that goes silent
  # because a Win32 call returned nothing is worse than one that occasionally reads while the player is
  # elsewhere. Like PokeAccess::Keyboard this knows nothing about the mod (no Config, no speech, no key
  # semantics); the decision of what to do with the answer belongs to PokeAccess::Keys.
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

    # True while the game window is foreground. GetAsyncKeyState reads keys even unfocused, so this
    # stops the mod firing while the player types elsewhere. Fail-safe: returns true if focus is unreadable.
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
