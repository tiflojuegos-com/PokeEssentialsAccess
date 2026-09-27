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

  # Evaluates the toolkit once the game is ready for it (see ready?).
  def self.try_load
    return if @loaded
    @frames += 1
    unless ready?
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
      end
    end
  end
end

AccessPreload.mark_started
