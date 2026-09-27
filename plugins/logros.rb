# Achievements (Logros_Scene) in its two shapes: this hook reads the showTexts one, and stands down while
# LogrosIndexed (the indexed pbUpdate loop, below) owns the scene.
PokeAccess::Hooks.after_hook("Logros_Scene", :showTexts, :optional => true) do |scene, _r, args|
  next if (PokeAccess::LogrosIndexed.watching? rescue false)
  logros = scene.instance_variable_get(:@logros)
  i = args[0]
  if logros && i && i >= 0 && i < logros.size
    t = PokeAccess.logro_indexed_text(logros[i])
    PokeAccess.speak(t, true)
  end
end

module PokeAccess
  # The indexed Logros screen: a pbUpdate loop moves @indexSel over @logros (LogroIcon name/desc/status).
  module LogrosIndexed
    @scene = nil; @last = nil
    def self.watch(s); @scene = s; @last = nil; end
    def self.unwatch; @scene = nil; @last = nil; end

    # True while this variant owns the scene, so the showTexts hook stands down.
    def self.watching?; !@scene.nil?; end

    # The focused entry's dedup key: cursor, description scroll (only while descriptions are said) and status.
    def self.key_of(s)
      idx = PokeAccess.ivar(s, :@indexSel)
      scroll = PokeAccess::Verbosity.descriptions? ? PokeAccess.ivar(s, :@descOffset) : nil
      [idx, scroll, (PokeAccess.ivar(s, :@logros)[idx].status rescue nil)]
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

  # One achievement's name, status and description as its entry gives them; a hidden one showing the copy's
  # placeholders (NOMBREOCULTO) is said as painted. 3 and 1 stand in where the constants sit in a class.
  def self.logro_indexed_text(l)
    nm = (l.name rescue nil)
    st = (l.status rescue nil)
    comp = (::LOGRO_COMPLETADO rescue 3); ocul = (::LOGRO_OCULTO rescue 1)
    d = (l.desc rescue nil)
    desc = (d && !d.to_s.empty?) ? PokeAccess::KeyHints.localize(clean(d), nil, true) : nil
    if st == ocul && logro_placeholder?(nm)
      line = desc ? "#{nm}. #{desc}" : nm.to_s
      PokeAccess::Info.set_info(:text, line)
      return line
    end
    earned = !logro_reward_state.nil? && st == logro_reward_state
    status = if st == comp then I18n.t(:ach_done)
             elsif earned then I18n.t(:ach_earned)
             elsif st == ocul then I18n.t(:ach_locked)
             else I18n.t(:ach_pending)
             end
    head = "#{nm}, #{status}"
    PokeAccess::Info.set_info(:text, desc ? "#{head}. #{desc}" : head)
    line = desc && PokeAccess::Verbosity.descriptions? ? "#{head}. #{desc}" : head
    r = PokeAccess::Verbosity.hints? ? reward_note(st) : nil
    return line unless r
    line =~ /[.!?]\z/ ? "#{line} #{r}" : "#{line}. #{r}"
  rescue StandardError
    nil
  end

  # True when a name is the copy's own placeholder for a hidden achievement (NOMBREOCULTO, top level or in Logros).
  def self.logro_placeholder?(nm)
    ph = (::NOMBREOCULTO rescue nil) || (::Logros::NOMBREOCULTO rescue nil)
    !ph.nil? && nm.to_s == ph.to_s
  end

  # The status of an achievement earned with its reward unclaimed (Logros::LOGRO_ACTIVO, in one copy), or nil.
  def self.logro_reward_state
    (::Logros::LOGRO_ACTIVO rescue nil)
  end

  # The line that copy paints under an earned achievement, with the key it names, or nil.
  def self.reward_note(st)
    active = logro_reward_state
    return nil if active.nil? || st != active
    painted = (_INTL("[{1}]: " + _INTL("Obtener recompensa"), ::KeybindingReader.key_name(:USE)) rescue nil)
    painted ? PokeAccess::KeyHints.localize(clean(painted)) : I18n.t(:ach_reward)
  rescue StandardError
    nil
  end
end

# Holds the scene during its pbUpdate loop, for the indexed variant only (the one with @indexSel).
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

# A diag bench of the per-frame poll; @last is pinned to the live key (key_of) first, so polling speaks nothing.
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
