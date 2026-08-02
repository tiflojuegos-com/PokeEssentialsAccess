module PokeAccess
  # Voice constants (prism drives NVDA/JAWS/SAPI/UIA/ZDSR and more; UTF-8 direct). prism_pea.dll is the
  # mod's flat cdecl bridge over prism.dll's handle-based API (source: bridge/prism_pea.c); both DLLs
  # live per-arch in lib/, which SetDllDirectoryA adds to the search path so the bridge finds its engine.
  # Eight of the bridge's nine exports are bound here. The ninth, PeaShutdown, is deliberately left
  # unbound: the mod has no teardown point. The game ends by the process dying (Windows frees the backend),
  # the Ctrl+Alt+F8 toggle is a reconnect and not a release (see retry_init!), and a script reload finds
  # the DLL still loaded with a live backend. Binding it would only invite a call that at best does
  # nothing and at worst cuts the reader off mid-line.
  (Win32API.new("kernel32", "SetDllDirectoryA", ["p"], "i").call(DLL_DIR + "\0") rescue nil)
  PEA_INIT     = (Win32API.new("prism_pea.dll", "PeaInitialize",  [],         "i") rescue nil)
  PEA_SPEAK    = (Win32API.new("prism_pea.dll", "PeaSpeak",       ["p", "i"], "i") rescue nil)
  PEA_STOP     = (Win32API.new("prism_pea.dll", "PeaStop",        [],         "i") rescue nil)
  PEA_PAUSE    = (Win32API.new("prism_pea.dll", "PeaPause",       [],         "i") rescue nil)
  PEA_RESUME   = (Win32API.new("prism_pea.dll", "PeaResume",      [],         "i") rescue nil)
  PEA_SPEAKING = (Win32API.new("prism_pea.dll", "PeaIsSpeaking",  [],         "i") rescue nil)
  PEA_BRAILLE  = (Win32API.new("prism_pea.dll", "PeaBraille",     ["p"],      "i") rescue nil)
  PEA_BACKEND  = (Win32API.new("prism_pea.dll", "PeaBackendName", [],         "p") rescue nil)
  @ready = false
  @init_attempted = false

  # Initialises the screen-reader bridge ONCE, honouring PeaInitialize's return value -- it used to be
  # ignored, so a total failure (no speech backend could start) left the mod mute for the whole session
  # with no trace and no way back. A failure logs once and stays failed: there is deliberately NO
  # background retry loop (an init sweep per speak would be constant busywork); the player's gesture for
  # "the voice is not up, reconnect" is toggling the mod off/on with Ctrl+Alt+F8, which calls retry_init!.
  # A reader started AFTER a successful init needs none of this: the bridge re-picks the best backend on
  # any Speak that fails.
  def self.init_speech!
    return @ready if @ready || @init_attempted
    @init_attempted = true
    return false unless PEA_INIT
    @ready = ((PEA_INIT.call rescue 0) != 0)
    log_once("prism_init", "PeaInitialize failed (no speech backend could start)") unless @ready
    @ready
  rescue StandardError
    false
  end

  # Forgets a failed init so the next speak tries again -- wired to the Ctrl+Alt+F8 mod toggle (turning
  # the mod back on is the natural "reconnect the voice" gesture; nothing retries in the background).
  def self.retry_init!
    @init_attempted = false unless @ready
    init_speech!
  end

  # Whether the bridge is up (a backend was acquired). The diag reads this; readers never need to.
  def self.speech_ready?; @ready; end

  # An observer for everything spoken, or nil. The ONE extension point the session recorder needs to
  # transcribe a play session without a single hook of its own inside the readers; nil by default, so
  # the cost of nobody listening is one nil check per line. A raising observer is swallowed: an
  # instrument must never be able to silence the mod.
  def self.on_speak=(cb); @on_speak = cb; end
  def self.on_speak; @on_speak; end

  # Speaks text through the active screen reader. param interrupt true cuts current speech, false queues.
  def self.speak(text, interrupt = true)
    return unless PEA_SPEAK
    return unless init_speech!
    text = text.to_s.gsub(/\s+/, " ").strip
    return if text.empty?
    @last_spoken = text
    (@on_speak.call(text, interrupt) rescue nil) if @on_speak
    PEA_SPEAK.call(text + "\0", interrupt ? 1 : 0)
  rescue StandardError => e
    write_marker("speak_error: #{format_error(e)}\n")
  end

  # Speaks a line of game text: strips its RPG Maker control codes (\PN, \V[n], \C[n]...) via clean, then
  # speaks. The common shape for voicing text that came from the game rather than a ready i18n string; readers
  # that already hold a clean line call speak directly. param interrupt true cuts current speech, false queues.
  def self.speak_clean(text, interrupt = true)
    speak(clean(text), interrupt)
  end

  # Silences the reader immediately without speaking anything new. Returns true if the backend obeyed.
  def self.stop_speech
    return false unless PEA_STOP && @ready
    (PEA_STOP.call rescue 0) != 0
  end

  # Pauses / resumes ongoing speech. Backend-dependent (SAPI and UIA honour it; NVDA does not) -- false
  # means "not supported or nothing to do", never an error worth surfacing.
  def self.pause_speech
    return false unless PEA_PAUSE && @ready
    (PEA_PAUSE.call rescue 0) != 0
  end

  def self.resume_speech
    return false unless PEA_RESUME && @ready
    (PEA_RESUME.call rescue 0) != 0
  end

  # Whether the reader is still voicing something: true/false, or nil when the backend cannot tell
  # (NVDA gains this with NvdaController3; JAWS and SAPI already report it). The future speech scheduler
  # keys on this -- callers must treat nil as "unknown", not as silence. Matched by exact value, not
  # sign: mkxp-z's Win32API returns the shim's -1 as unsigned 4294967295, which a `< 0` test misses.
  def self.speaking?
    return nil unless PEA_SPEAKING && @ready
    v = (PEA_SPEAKING.call rescue -1)
    return true if v == 1
    return false if v == 0
    nil
  end

  # Sends text to the active braille display (no-op false without one). UTF-8, same as speak.
  def self.braille(text)
    return false unless PEA_BRAILLE && init_speech!
    text = text.to_s
    return false if text.empty?
    (PEA_BRAILLE.call(text + "\0") rescue 0) != 0
  end

  # Sends unicode codepoints (e.g. braille-pattern cells U+28xx) to the braille display.
  def self.braille_codepoints(cps)
    braille(codepoints_to_utf8(cps))
  end

  # The active backend's name ("NVDA", "JAWS", "SAPI 5"...) for the diagnostics, or "" when down.
  def self.speech_backend
    return "" unless PEA_BACKEND && @ready
    (PEA_BACKEND.call rescue "").to_s
  end

  # Unicode codepoints to UTF-8 bytes, 1.8.7-safe. BMP only (covers braille patterns and all game text
  # the mod handles); out-of-range codepoints are skipped rather than encoded as invalid bytes.
  def self.codepoints_to_utf8(cps)
    bytes = []
    cps.each do |cp|
      next if cp.nil? || cp < 0 || cp > 0xFFFF
      if cp < 0x80
        bytes.push(cp)
      elsif cp < 0x800
        bytes.push(0xC0 | (cp >> 6), 0x80 | (cp & 0x3F))
      else
        bytes.push(0xE0 | (cp >> 12), 0x80 | ((cp >> 6) & 0x3F), 0x80 | (cp & 0x3F))
      end
    end
    bytes.pack("C*")
  end

  # The last non-empty line spoken, for the spoken diagnostic ("last: ..."), or nil if nothing spoken yet.
  def self.last_spoken; @last_spoken; end
end

PokeAccess.write_marker("cargado ruby=#{RUBY_VERSION rescue '?'} prism=#{!PokeAccess::PEA_SPEAK.nil?}\n")
