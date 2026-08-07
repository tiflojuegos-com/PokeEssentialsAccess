# Achievements (Logros_Scene), a common fangame addon, in its two shapes.
#
# This hook serves the showTexts shape, which fires as the list is navigated. Every copy surveyed uses the
# other one -- an indexed pbUpdate loop, handled by LogrosIndexed below -- so this stands down whenever that
# module owns the scene.
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
  # The indexed Logros screen: a pbUpdate loop moves @indexSel over @logros (LogroIcon name/desc/status)
  # and draws the focused one. No showTexts.
  module LogrosIndexed
    @scene = nil; @last = nil
    def self.watch(s); @scene = s; @last = nil; end
    def self.unwatch; @scene = nil; @last = nil; end

    # True while this variant owns the scene, so the showTexts hook stands down.
    def self.watching?; !@scene.nil?; end

    # The dedup key of the focused entry: cursor, description scroll and status.
    #
    # All three belong in it: a long description pages in place at the same index, and claiming a reward
    # changes the status without moving anything. Public so the diagnostic can pin @last to the same shape.
    def self.key_of(s)
      idx = PokeAccess.ivar(s, :@indexSel)
      [idx, PokeAccess.ivar(s, :@descOffset), (PokeAccess.ivar(s, :@logros)[idx].status rescue nil)]
    end

    # Reads the focused achievement when the cursor moves, the description scrolls, or the status changes.
    def self.poll
      s = @scene
      return unless s
      key = key_of(s)
      return if key[0].nil? || key == @last
      @last = key
      l = (PokeAccess.ivar(s, :@logros)[key[0]] rescue nil)
      PokeAccess.speak(PokeAccess.logro_indexed_text(l), true) if l
    rescue StandardError
      nil
    end
  end

  # Name, status and description of one achievement, as the entry hands them over.
  #
  # The description is never suppressed here: whether an unearned achievement hides its text is already
  # decided inside name/desc by each copy. Status 1 is the declared-but-unlocked default, not "secret".
  # The status constants are top level in some copies and inside a Logros class in others, so the 3/2/1
  # fallback is what answers on the latter.
  def self.logro_indexed_text(l)
    nm = (l.name rescue nil)
    st = (l.status rescue nil)
    comp = (::LOGRO_COMPLETADO rescue 3); ocul = (::LOGRO_OCULTO rescue 1)
    status = (st == comp) ? I18n.t(:ach_done) : ((st == ocul) ? I18n.t(:ach_locked) : I18n.t(:ach_pending))
    d = (l.desc rescue nil)
    line = (d && !d.to_s.empty?) ? "#{nm}, #{status}. #{clean(d)}" : "#{nm}, #{status}"
    r = reward_note(st)
    r ? "#{line}. #{r}" : line
  rescue StandardError
    nil
  end

  # The "press USE to collect" line, or nil. Only one copy has that state, and its LOGRO_ACTIVO means
  # earned-and-unclaimed rather than not-yet-earned, so it is read from that copy's own constant.
  def self.reward_note(st)
    active = (::Logros::LOGRO_ACTIVO rescue nil)
    return nil if active.nil? || st != active
    I18n.t(:ach_reward)
  rescue StandardError
    nil
  end
end

# Holds the scene during its pbUpdate loop, but only for the indexed variant, which is the one with
# @indexSel.
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

PokeAccess::Keys.on_frame { PokeAccess::LogrosIndexed.poll }

# This list is the mod's only per-frame poller, so it is the one thing that can make a custom menu lag.
# The bench lives here and not in core's dump, because core must not name a plugin.
#
# @last is pinned to the live key before timing: poll SPEAKS on a difference, and pressing the diagnostic
# key must not change what the player hears. It is pinned through key_of, the same builder poll uses, so the
# two cannot drift apart.
PokeAccess::Keys.register_diag_section(:logros_poll, :perf) do |o|
  lg = (PokeAccess::LogrosIndexed.instance_variable_get(:@scene) rescue :none)
  o.push("logros_poll: scene=#{lg.nil? ? 'idle' : (lg == :none ? 'absent' : 'ACTIVE')}")
  last0 = (PokeAccess::LogrosIndexed.instance_variable_get(:@last) rescue nil)
  (PokeAccess::LogrosIndexed.instance_variable_set(:@last, PokeAccess::LogrosIndexed.key_of(lg)) rescue nil) if lg && lg != :none
  t0 = PokeAccess.clock
  5000.times { (PokeAccess::LogrosIndexed.poll rescue nil) }
  (PokeAccess::LogrosIndexed.instance_variable_set(:@last, last0) rescue nil)
  o.push("logros_poll: 5000x poll = #{sprintf('%.2f', (PokeAccess.clock - t0) * 1000)}ms (idle should be ~0)")
end
