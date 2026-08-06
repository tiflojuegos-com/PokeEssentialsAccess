# Achievements (Logros_Scene), a common fangame addon. showTexts(index)
# runs as the list is navigated; installs only where the class exists and reads defensively.
PokeAccess::Hooks.after_hook("Logros_Scene", :showTexts, :optional => true) do |scene, _r, args|
  next if (PokeAccess::LogrosIndexed.watching? rescue false)
  logros = scene.instance_variable_get(:@logros)
  i = args[0]
  if logros && i && i >= 0 && i < logros.size
    t = PokeAccess.logro_indexed_text(logros[i])
    PokeAccess.speak(t, true) if t && !t.to_s.empty?
  end
end

module PokeAccess
  # An indexed Logros screen (seen in the wild) with no showTexts: a pbUpdate loop moves @indexSel over
  # @logros (LogroIcon name/desc/status), drawing the focused one. Kept apart from the showTexts variant.
  module LogrosIndexed
    @scene = nil; @last = nil
    def self.watch(s); @scene = s; @last = nil; end
    def self.unwatch; @scene = nil; @last = nil; end
    # True while this indexed variant owns the scene, so the showTexts hook stands down (avoids double read
    # on games whose Logros_Scene has BOTH @indexSel and showTexts).
    def self.watching?; !@scene.nil?; end

    # Reads the focused achievement when the cursor moves.
    def self.poll
      s = @scene
      return unless s
      idx = PokeAccess.ivar(s, :@indexSel)
      logros = PokeAccess.ivar(s, :@logros)
      return if idx.nil? || logros.nil? || idx == @last
      @last = idx
      l = (logros[idx] rescue nil)
      PokeAccess.speak(PokeAccess.logro_indexed_text(l), true) if l
    rescue StandardError
      nil
    end
  end

  # Name + status (done/pending/hidden) and, unless hidden, the description. Status constants are
  # top-level in the game (default to the standard 3/2/1 if absent).
  def self.logro_indexed_text(l)
    nm = (l.name rescue nil)
    st = (l.status rescue nil)
    comp = (::LOGRO_COMPLETADO rescue 3); ocul = (::LOGRO_OCULTO rescue 1)
    status = (st == comp) ? I18n.t(:ach_done) : ((st == ocul) ? I18n.t(:ach_hidden) : I18n.t(:ach_pending))
    return "#{nm}, #{status}" if st == ocul
    d = (l.desc rescue nil)
    (d && !d.to_s.empty?) ? "#{nm}, #{status}. #{clean(d)}" : "#{nm}, #{status}"
  rescue StandardError
    nil
  end
end

# Hold the indexed Logros scene during its pbUpdate loop, but only the indexed variant (it has @indexSel);
# the showTexts variant above lacks it, so it is left untouched.
PokeAccess::Hooks.around_hook("Logros_Scene", :pbUpdate, :optional => true) do |scene, call_next, _a|
  if !(scene.instance_variable_get(:@indexSel) rescue nil).nil?
    PokeAccess::LogrosIndexed.watch(scene)
    begin
      call_next.call
    ensure
      PokeAccess::LogrosIndexed.unwatch
    end
  else
    call_next.call
  end
end

# Per-frame poll while the indexed Logros scene is active (via the shared per-frame registry).
PokeAccess::Keys.on_frame { PokeAccess::LogrosIndexed.poll }

# The achievements list is the mod's one per-frame poller, so it is also the one thing that can make a
# custom menu lag. Registered as a diagnostic section rather than written into the core's own dump: the
# core must not name a plugin, and a section keeps the bench with the code it measures.
PokeAccess::Keys.register_diag_section(:logros_poll, :perf) do |o|
  lg = (PokeAccess::LogrosIndexed.instance_variable_get(:@scene) rescue :none)
  o.push("logros_poll: scene=#{lg.nil? ? 'idle' : (lg == :none ? 'absent' : 'ACTIVE')}")
  # Pin @last to the live index first: poll SPEAKS when it differs, so with the screen open the first of
  # the 5000 iterations would announce an entry. Pressing the diagnostic key must not change what the
  # player hears. The other 4999 take the same early-return path, so the number stays comparable.
  last0 = (PokeAccess::LogrosIndexed.instance_variable_get(:@last) rescue nil)
  (PokeAccess::LogrosIndexed.instance_variable_set(:@last, PokeAccess.ivar(lg, :@indexSel)) rescue nil) if lg && lg != :none
  t0 = PokeAccess.clock
  5000.times { (PokeAccess::LogrosIndexed.poll rescue nil) }
  (PokeAccess::LogrosIndexed.instance_variable_set(:@last, last0) rescue nil)
  o.push("logros_poll: 5000x poll = #{sprintf('%.2f', (PokeAccess.clock - t0) * 1000)}ms (idle should be ~0)")
end
