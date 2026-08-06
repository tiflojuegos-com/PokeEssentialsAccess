# Achievements (Logros_Scene), a common fangame addon.
#
# Two shapes. The one below reads showTexts(index), which runs as the list is navigated. Every copy surveyed
# so far turns out to use the OTHER shape -- an indexed pbUpdate loop, handled by LogrosIndexed further down,
# which stands this hook down while it owns the scene -- so this path is the fallback for a copy that has
# showTexts without @indexSel rather than something in daily use. Installs only where the class exists and
# reads defensively.
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

    # Reads the focused achievement when the cursor moves, and again when its description is scrolled.
    #
    # The scroll offset belongs in the key. A long description does not fit the panel, so the screen pages
    # through it with a key that redraws the SAME entry at a new offset; keyed on the index alone, every page
    # after the first was silent -- and one game's very first achievement is a tutorial telling the player to
    # press that key.
    def self.poll
      s = @scene
      return unless s
      idx = PokeAccess.ivar(s, :@indexSel)
      logros = PokeAccess.ivar(s, :@logros)
      l = (logros[idx] rescue nil)
      # The STATUS is in the key too. Collecting a reward changes it in place -- the cursor has not moved and
      # neither has the scroll -- so keyed on those two alone the one moment the player is waiting to hear
      # about, the achievement flipping to claimed, was the one moment this stayed quiet.
      key = [idx, PokeAccess.ivar(s, :@descOffset), (l.status rescue nil)]
      return if idx.nil? || logros.nil? || key == @last
      @last = key
      PokeAccess.speak(PokeAccess.logro_indexed_text(l), true) if l
    rescue StandardError
      nil
    end
  end

  # Name, status and description, exactly as the entry hands them over.
  #
  # The description is NEVER suppressed. Whether an unearned achievement hides its text is the game's call,
  # and every copy has already made it inside name/desc: one substitutes a placeholder there, the others
  # return the real strings and paint them. Adding a second layer of hiding on top only broke the copies
  # that hide nothing -- their entire list read as "hidden" with the description withheld, on a screen that
  # was showing both.
  #
  # State 1 is not "secret" either: it is what every achievement is declared with before it is unlocked.
  # The constants come from the game, top level in some copies and inside its Logros class in others -- so
  # the :: lookup fails on the latter and the standard 3/2/1 fallback is what actually answers there.
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

  # "Press USE to collect" -- the line the screen paints over the description of an achievement that is
  # earned but unclaimed, and the only thing on it a player can act on. Gated on the copy that HAS that
  # state: it keeps its constants inside a Logros module of its own, and its ACTIVO means earned-and-owed
  # rather than not-yet-earned, which is the opposite of what the bare number means elsewhere.
  def self.reward_note(st)
    active = (::Logros::LOGRO_ACTIVO rescue nil)
    return nil if active.nil? || st != active
    I18n.t(:ach_reward)
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
  (PokeAccess::LogrosIndexed.instance_variable_set(:@last, [PokeAccess.ivar(lg, :@indexSel), PokeAccess.ivar(lg, :@descOffset)]) rescue nil) if lg && lg != :none
  t0 = PokeAccess.clock
  5000.times { (PokeAccess::LogrosIndexed.poll rescue nil) }
  (PokeAccess::LogrosIndexed.instance_variable_set(:@last, last0) rescue nil)
  o.push("logros_poll: 5000x poll = #{sprintf('%.2f', (PokeAccess.clock - t0) * 1000)}ms (idle should be ~0)")
end
