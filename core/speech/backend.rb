module PokeAccess
  # The screen-reader bridge: prism_pea.dll (bridge/prism_pea.c), a flat cdecl layer over prism.dll, both per arch in
  # lib/ (added to the DLL search path). PeaShutdown stays unbound on purpose: the mod has no teardown point, and a
  # call could cut the reader off mid-line.
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

  # Initialises the bridge once and returns whether it is up; a failure stays until retry_init! (Ctrl+Alt+F8).
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

  # Forgets a failed init and tries again; called by the Ctrl+Alt+F8 mod toggle.
  def self.retry_init!
    @init_attempted = false unless @ready
    init_speech!
  end

  # Whether the bridge is up (a backend was acquired). The diag reads this; readers never need to.
  def self.speech_ready?; @ready; end

  # Hands a ready line to the screen reader, the one place text leaves the mod (the test harness replaces it);
  # interrupt cuts current speech, else it queues.
  def self.voice_out(text, interrupt)
    return unless PEA_SPEAK
    return unless init_speech!
    PEA_SPEAK.call(text + "\0", interrupt ? 1 : 0)
  rescue StandardError => e
    write_marker("speak_error: #{format_error(e)}\n")
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

  # Whether the reader is still voicing something, or nil when the backend cannot tell (not silence). Matched by
  # exact value: mkxp-z's Win32API returns -1 as 4294967295.
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
end

PokeAccess.write_marker("cargado ruby=#{RUBY_VERSION rescue '?'} prism=#{!PokeAccess::PEA_SPEAK.nil?}\n")
