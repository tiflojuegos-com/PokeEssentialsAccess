# mkxp-z loader via preloadScript in mkxp.json. Preload scripts run before Scripts.rxdata, when the game
# classes do not exist yet, so loading is deferred: Graphics.update is wrapped and boot.rb is evaluated
# once the main loop is running (trigger: $scene being set, or a frame-count fallback for builds that
# never set it). Reversible: no Scripts.rxdata edit. eval is intentional and safe (boot.rb is our own
# trusted local file in a fixed folder).
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

  # True once the game has finished evaluating its script list. pbCallTitle is defined by Main, the LAST
  # script of every surveyed source, and it only builds the first scene, so its presence means every game
  # class exists (the animated-title plugins that redefine it run from Main too, so they cannot arrive
  # earlier). Without this the frame fallback fired into the first-run language prompt, which four gen-6
  # games run at TOP LEVEL two thirds of the way down their list, and every hook whose class came later
  # bound nothing for the whole session; the price is that the language list itself goes unread on that
  # one run. A top-level def lands as a PRIVATE method of Object, so both predicates are checked.
  def self.scripts_done?
    Object.private_method_defined?(:pbCallTitle) || Object.method_defined?(:pbCallTitle)
  rescue StandardError
    false
  end

  # Whether the toolkit can be loaded on this frame: the main loop is running (Main assigns $scene before
  # the first scene runs, so the title screen is already covered), or the frame fallback expired AND the
  # script list finished, which is the safety net for a build that never assigns $scene.
  def self.ready?
    return true if defined?($scene) && $scene
    @frames >= READY_FRAME && scripts_done?
  end

  # Writes one line, once, when the game has run long past the fallback without ever becoming ready. A
  # player sitting on the first-run language prompt passes it in well under a minute, and that is not a
  # fault -- so the line SAYS which of the two it is: "waiting for the script list" is that prompt, and
  # "stalled" is the real thing, the list finished and the mod still not loaded.
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
