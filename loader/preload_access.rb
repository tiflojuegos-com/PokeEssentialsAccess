# mkxp-z loader (preloadScript in mkxp.json), run before Scripts.rxdata: wraps Graphics.update and evals our
# own accessibility/boot.rb once the game is ready (ready?). Leaves Scripts.rxdata untouched.
module AccessPreload
  PATH        = "accessibility/boot.rb"
  ERROR_LOG   = "accessibility/data/loader_error.txt"
  START_MARK  = "accessibility/data/preload_started.txt"
  READY_FRAME = 120
  STALL_FRAME = 1800
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

  # Notes an F12 reset (mkxp-z's Reset, raised out of Graphics.update) once the toolkit is loaded: the engine then
  # evaluates the game's scripts anew, not this preload, and their definitions replace the toolkit's wrappers.
  def self.note_reset(e)
    return unless @loaded && defined?(::Reset) && e.is_a?(::Reset)
    @reset = true
    @frames = 0
    @title = title_method
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
        r = update__access_preload(*a)
        AccessPreload.try_load
        r
      rescue Exception => e
        AccessPreload.note_reset(e)
        raise
      end
    end
  end
end

# A stock language prompt can run while scripts are still loading. Do not boot
# core early: many game classes have not been defined. Use the same idempotent
# native bridge for this small prompt, then leave normal speech to core.
module AccessPreload
  module EarlyLanguage
    def self.prompt?
      caller.any? { |line| line =~ /[`'#.]pbChooseLanguage['`]\z/ }
    end

    def self.tick
      unless prompt?
        @last = nil
        return
      end
      return unless Object.const_defined?(:LANGUAGES)
      return unless Object.const_defined?(:Window_CommandPokemon)
      languages = Object.const_get(:LANGUAGES)
      return unless languages.is_a?(Array) && languages.length >= 2
      return unless languages.all? { |row| row.is_a?(Array) && row[0].is_a?(String) }
      labels = languages.map { |row| row[0] }
      candidates = []
      ObjectSpace.each_object(Object.const_get(:Window_CommandPokemon)) do |window|
        next if window.disposed? || !window.visible || !window.active
        next unless window.commands == labels
        next unless window.index.is_a?(Integer) && window.index >= 0 && window.index < labels.length
        candidates.push(window)
      end
      return unless candidates.length == 1
      window = candidates[0]
      text = window.commands[window.index]
      state = [window, window.index, text.dup]
      return if state == @last
      @last = state
      if speak(text)
        @sequence = (@sequence || 0) + 1
        @announcement = [@sequence, text.dup]
      end
    rescue StandardError => error
      unless @logged_error
        @logged_error = true
        File.open(AccessPreload::ERROR_LOG, 'a') { |file| file.puts("early language: #{error.class}: #{error.message}") } rescue nil
      end
    end

    # Read-only diagnostic state. It records a successful native dispatch;
    # observing actual screen-reader synthesis remains a separate check.
    def self.announcement
      @announcement ? @announcement.dup : nil
    end

    def self.speak(text)
      unless @bridge_attempted
        @bridge_attempted = true
        Win32API.new('kernel32', 'SetDllDirectoryA', ['p'], 'i').call("accessibility/lib\0")
        init = Win32API.new('prism_pea.dll', 'PeaInitialize', [], 'i')
        @speak = Win32API.new('prism_pea.dll', 'PeaSpeak', ['p', 'i'], 'i')
        @braille = (Win32API.new('prism_pea.dll', 'PeaBraille', ['p'], 'i') rescue nil)
        @bridge_ready = init.call != 0
      end
      return false unless @bridge_ready
      result = @speak.call(text + "\0", 1) != 0
      @braille.call(text + "\0") if @braille
      result
    end
  end
end

AccessPreload.mark_started
