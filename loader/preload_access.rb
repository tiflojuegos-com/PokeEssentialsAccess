# mkxp-z loader (preloadScript in mkxp.json), run before Scripts.rxdata: wraps Graphics.update and evals our
# own accessibility/boot.rb once the game is ready (ready?), and answers F12 by starting the game anew (on_raise).
# Leaves Scripts.rxdata untouched.
module AccessPreload
  PATH        = "accessibility/boot.rb"
  ERROR_LOG   = "accessibility/data/loader_error.txt"
  START_MARK  = "accessibility/data/preload_started.txt"
  READY_FRAME = 120
  STALL_FRAME = 1800
  # The Windows calls relaunch makes; nil where the engine has no Win32API.
  MODULE_FILE    = (Win32API.new("kernel32", "GetModuleFileNameW", "lpl", "l") rescue nil)
  CREATE_PROCESS = (Win32API.new("kernel32", "CreateProcessW", "lpllilllpp", "i") rescue nil)
  CLOSE_HANDLE   = (Win32API.new("kernel32", "CloseHandle", "l", "i") rescue nil)
  @loaded = false
  @stalled = false
  @frames = 0
  @reset = false
  @title = nil

  # Records that the preload script itself executed, independent of boot succeeding, so a missing boot
  # marker can be told apart from preloadScript not running at all.
  def self.mark_started
    File.open(START_MARK, "w") { |f| f.write("preload ok ruby=#{RUBY_VERSION rescue '?'}\n") }
  rescue StandardError
  end

  # True once the game's script list is evaluated: pbCallTitle is defined by Main, the last script. A top-level
  # def is a private method of Object, so both predicates are checked.
  def self.scripts_done?
    Object.private_method_defined?(:pbCallTitle) || Object.method_defined?(:pbCallTitle)
  rescue StandardError
    false
  end

  # Whether the game still evaluates its scripts on a thread of its own (Rejuvenation's ThreadLoader sets $scene before
  # that thread ends), whose classes the toolkit would otherwise hook before they exist.
  def self.scripts_loading?
    return false unless defined?(ThreadLoader)
    t = ThreadLoader.send(:class_variable_get, :@@scriptLoadThread)
    t.is_a?(Thread) && t.alive?
  rescue StandardError
    false
  end

  # Whether the toolkit can load this frame: no script thread is still running, and $scene is set or, for a build
  # that never sets it, READY_FRAME frames have passed and the script list is done.
  def self.ready?
    return false if scripts_loading?
    return true if defined?($scene) && $scene
    @frames >= READY_FRAME && scripts_done?
  end

  # Notes once in the start marker that STALL_FRAME frames passed without becoming ready, with scripts_done
  # telling a first-run language prompt from a real stall.
  def self.note_stall
    return if @stalled
    @stalled = true
    File.open(START_MARK, "a") do |f|
      f.write("stalled: #{@frames} frames, scene=#{(defined?($scene) && $scene) ? 'set' : 'nil'}, scripts_done=#{scripts_done?}\n")
    end
  rescue StandardError
  end

  # The game's pbCallTitle as defined now (Main, the last script, defines it); nil in a game without one.
  def self.title_method
    Object.instance_method(:pbCallTitle)
  rescue StandardError
    nil
  end

  # What an error out of a Graphics call that runs frames, or out of an engine message box, becomes. mkxp-z answers F12 by raising Reset there and then
  # evaluating the game's scripts anew in this process, which some games cannot survive (an engine method they alias
  # ends up calling itself) and others answer by starting their original player, without the toolkit: the game starts
  # anew in a process of its own instead (relaunch), and this one ends. Where no process can be started, the reset goes
  # on here (note_reset). Any other error passes unchanged.
  def self.on_raise(e)
    return e unless defined?(::Reset) && e.is_a?(::Reset)
    if relaunch
      @relaunched = true
      return SystemExit.new
    end
    note_reset
    e
  end

  # Ends this process at once when the game went on after a relaunch, having caught the SystemExit: two copies of it
  # would read the same keys.
  def self.leave_if_relaunched
    exit!(0) if @relaunched
  end

  # Notes a reset carried out in this process once the toolkit is loaded: the engine evaluates the game's scripts
  # anew, not this preload, and their definitions replace the toolkit's wrappers until after_reset puts them back.
  def self.note_reset
    return unless @loaded
    @reset = true
    @frames = 0
    @title = title_method
  end

  # Starts this process's executable anew, without arguments, in this process's folder and environment; true once
  # Windows started it.
  def self.relaunch
    return false unless MODULE_FILE && CREATE_PROCESS
    units = 32768
    buf = binary("\0" * (units * 2))
    n = MODULE_FILE.call(0, buf, units)
    return false if n <= 0 || n >= units
    line = binary("\"\0") + buf[0, n * 2] + binary("\"\0\0\0")
    wide = ["a"].pack("p").size == 8
    startup = binary([wide ? 104 : 68].pack("L") + "\0" * (wide ? 100 : 64))
    info = binary("\0" * (wide ? 24 : 16))
    return false if CREATE_PROCESS.call(0, line, 0, 0, 0, 0, 0, 0, startup, info) == 0
    close_handles(info.unpack(wide ? "Q2" : "L2"))
    true
  rescue StandardError
    false
  end

  # Closes the handles CreateProcessW gave on the new process and its thread, which this one does not use.
  def self.close_handles(handles)
    handles.each { |h| CLOSE_HANDLE.call(h) } if CLOSE_HANDLE
  rescue StandardError
    nil
  end

  # The string as raw bytes, so a UTF-16 buffer is cut by byte on engines whose Ruby has encodings.
  def self.binary(s)
    s.send(:force_encoding, "ASCII-8BIT") if s.respond_to?(:force_encoding)
    s
  end

  # Once the game's scripts ran again (Main defined pbCallTitle anew, or READY_FRAME frames passed in a game without
  # it) and no script thread still loads, has the toolkit put back the wrappers they replaced.
  def self.after_reset
    @frames += 1
    return if scripts_loading?
    now = title_method
    return if now ? now == @title : @frames < READY_FRAME
    @reset = false
    PokeAccess::Hooks.after_reset if defined?(PokeAccess::Hooks) && PokeAccess::Hooks.respond_to?(:after_reset)
  rescue Exception => e
    raise if e.is_a?(SystemExit)
    (File.open(ERROR_LOG, "a") { |f| f.write("after reset: #{e.class}: #{e.message}\n") } rescue nil)
  end

  # Evaluates the toolkit once the game is ready for it (see ready?); after a reset, puts its wrappers back instead.
  def self.try_load
    return after_reset if @reset
    return if @loaded
    @frames += 1
    unless ready?
      EarlyLanguage.tick unless scripts_loading?
      note_stall if @frames >= STALL_FRAME
      return
    end
    @loaded = true
    begin
      eval(File.read(PATH), TOPLEVEL_BINDING, PATH)
    rescue Exception => e
      raise if e.is_a?(SystemExit)
      (File.open(ERROR_LOG, "w") { |f|
        f.write("#{e.class}: #{e.message}\n#{(e.backtrace || []).join("\n")}")
      } rescue nil)
    end
  end

  class << Graphics
    unless method_defined?(:update__access_preload)
      alias_method :update__access_preload, :update
      def update(*a)
        AccessPreload.leave_if_relaunched
        r = update__access_preload(*a)
        AccessPreload.try_load
        r
      rescue Exception => e
        raise AccessPreload.on_raise(e)
      end
    end
    %w[transition wait fadeout fadein freeze].each do |name|
      next unless method_defined?(name) && !method_defined?("#{name}__access_preload")
      alias_method "#{name}__access_preload", name
      define_method(name) do |*a|
        begin
          send("#{name}__access_preload", *a)
        rescue Exception => e
          raise AccessPreload.on_raise(e)
        end
      end
    end
  end
end

# The engine's message boxes wait for the player through frames of their own, where F12 raises Reset too.
module Kernel
  %w[msgbox print p].each do |name|
    next unless private_method_defined?(name) || method_defined?(name)
    next if private_method_defined?("#{name}__access_preload")
    alias_method "#{name}__access_preload", name
    private "#{name}__access_preload"
    define_method(name) do |*a|
      begin
        send("#{name}__access_preload", *a)
      rescue Exception => e
        raise AccessPreload.on_raise(e)
      end
    end
    private name
  end
end

module AccessPreload
  # The first-boot language picker (pbChooseLanguage over the LANGUAGES list) a game can show before the toolkit loads,
  # with most of the game's classes still undefined: its highlighted language is said through the screen-reader
  # bridge each time it changes, without booting the toolkit early.
  module EarlyLanguage
    # Says the picker's highlighted language when it changed since the last frame; forgets it outside the picker.
    # A failure is noted once in the loader log and the game goes on.
    def self.tick
      unless prompt?
        @last = nil
        return
      end
      window = picker
      return unless window
      state = [window, window.index]
      return if state == @last
      @last = state
      speak(window.commands[window.index])
    rescue StandardError => e
      return if @logged
      @logged = true
      (File.open(ERROR_LOG, "a") { |f| f.write("early language: #{e.class}: #{e.message}\n") } rescue nil)
    end

    # Whether the game is inside pbChooseLanguage now.
    def self.prompt?
      caller.any? { |line| line =~ /[`'#.]pbChooseLanguage['`]\z/ }
    end

    # The one visible, active command window that lists exactly the names in LANGUAGES, a language highlighted; nil
    # when there is none, or more than one.
    def self.picker
      return nil unless Object.const_defined?(:LANGUAGES) && Object.const_defined?(:Window_CommandPokemon)
      rows = Object.const_get(:LANGUAGES)
      return nil unless rows.is_a?(Array) && rows.length >= 2 && rows.all? { |r| r.is_a?(Array) && r[0].is_a?(String) }
      names = rows.map { |r| r[0] }
      found = []
      ObjectSpace.each_object(Object.const_get(:Window_CommandPokemon)) do |w|
        next if w.disposed? || !w.visible || !w.active || w.commands != names
        found.push(w) if w.index.is_a?(Integer) && w.index >= 0 && w.index < names.length
      end
      found.length == 1 ? found[0] : nil
    end

    # Hands the text to the screen-reader bridge, interrupting, and to a braille display. The bridge is set up on the
    # first call as the toolkit's speech backend sets it up; its initialization is idempotent, so the toolkit's own
    # later one finds it ready.
    def self.speak(text)
      unless @tried
        @tried = true
        Win32API.new("kernel32", "SetDllDirectoryA", "p", "i").call("accessibility/lib\0")
        @speak = Win32API.new("prism_pea.dll", "PeaSpeak", "pi", "i")
        @braille = (Win32API.new("prism_pea.dll", "PeaBraille", "p", "i") rescue nil)
        @ready = Win32API.new("prism_pea.dll", "PeaInitialize", "", "i").call != 0
      end
      return unless @ready
      @speak.call(text + "\0", 1)
      @braille.call(text + "\0") if @braille
    end
  end
end

AccessPreload.mark_started
