module PokeAccess
  # Hook helpers. Several hooks may wrap the same method: each registers a middleware and they chain
  # (an onion) around the original, so a new feature can never silently disable an existing hook.
  module Hooks
    @chains = {}
    @missing = []
    @body_logged = []
    @reg_seq = 0
    @active = []
    @suppressed = []

    # Reentrancy guard: a stack of the method names whose ORIGINAL is running, which is enough because the
    # game is single-threaded. An atomic after_hook pushes around its original and the dispatcher skips a
    # nested hooked call with a DIFFERENT name, so an inner hook cannot speak and consume the outer's dedup
    # before the outer -- the authoritative announcer -- runs. The SAME name passes, so a child reaching its
    # hooked parent through super still fires both.
    #
    # Correct only for an atomic announcer, one whose own body is the voice. Two kinds must run their
    # original UNGUARDED or they silence the readers that do the talking:
    #   - a CONTAINER (hook_container: true): a modal loop or scene opener that DELEGATES the announcement to
    #     hooked methods it drives, such as the battle command phase or any pbScene/pbStartScene/main.
    #   - a per-frame DRIVER (frame_hook): a method the engine calls every frame that can host a whole nested
    #     modal loop. Game_Player#update is one: gen-6 runs an entire wild battle inside it, so guarding it
    #     would pin :update for the fight and skip every battle reader as nested.
    #
    # Default is atomic, so a hook that says nothing keeps the safe behaviour. A before_hook body runs ahead
    # of the original, never competes for a dedup, and never guards it.
    def self.nested_other?(meth)
      !@active.empty? && @active.last != meth
    end

    # Records a dropped hook as "outer -> inner", for the diagnostic. Suppression is invisible by design, so
    # a hook wrongly registered on a container silences what it drives with no error and no failing test.
    # Often it is CORRECT, so the list is evidence and not a fault: what matters is a pair whose outer says
    # nothing. Capped and deduped, so it cannot grow with playtime.
    def self.note_suppressed(inner)
      outer = @active.last
      pair = "#{outer}>#{inner}"
      return if @suppressed.include?(pair) || @suppressed.length >= 40
      @suppressed.push(pair)
    end

    # The outer>inner pairs the guard has dropped this session (see note_suppressed).
    def self.suppressed; @suppressed; end

    # The class whose hooked method ran most recently: the only cheap answer to which screen the player is on
    # that survives a screen with its own blocking loop, which never becomes $scene. Set from the wrapper,
    # which every hooked call goes through, and read by the silence watch.
    def self.note_screen(cname); @screen = cname; end
    def self.screen; @screen; end

    # Runs the original of an atomic after-hook for meth with its name pushed on the active stack, always
    # popping (ensure) so a throwing original never leaves nested hooks permanently muted.
    def self.guarded(meth)
      @active.push(meth)
      begin
        yield
      ensure
        @active.pop
      end
    end

    # Bindings whose class exists but whose method does not -- almost always a typo'd method name (an
    # absent class is normal cross-game variance and is NOT recorded). Boot writes this to a marker.
    def self.missing; @missing; end

    # Registers a middleware around an instance method, chaining with any others already on it. Yields
    # (instance, call_next, args); call call_next to run the rest of the chain. The saved-original alias is
    # named per class and only methods defined ON the class count, so hooking a parent and then a child that
    # overrides the same method does not bypass the child.
    # param opts :optional declares the METHOD legitimately absent on some games, so the bind is skipped
    #   instead of landing in @missing, which keeps that list meaning "should exist here and does not"
    def self.wrap(cname, meth, opts = {}, &mw)
      k = PokeAccess.const_at(cname)
      return if k.nil?
      was_private = k.private_method_defined?(meth)
      unless k.method_defined?(meth) || was_private
        return if opts[:optional]
        @missing << "#{cname}##{meth}" unless @missing.include?("#{cname}##{meth}")
        return
      end
      key = "#{cname}##{meth}"
      fresh = !@chains.has_key?(key)
      (@chains[key] ||= []).push(mw)
      return unless fresh
      orig = "#{meth}__pa_orig_#{cname.gsub(/[^a-zA-Z0-9]/, '_')}".to_sym
      own = (k.instance_methods(false) + k.private_instance_methods(false)).map { |m| m.to_sym }
      k.send(:alias_method, orig, meth) unless own.include?(orig)
      chains = @chains
      k.send(:define_method, meth) do |*args, &blk|
        PokeAccess::Hooks.note_screen(cname)
        if PokeAccess::Hooks.nested_other?(meth)
          PokeAccess::Hooks.note_suppressed(key)
          return send(orig, *args, &blk)
        end
        call = lambda { send(orig, *args, &blk) }
        chains[key].reverse_each do |w|
          nxt = call
          call = lambda { w.call(self, nxt, args) }
        end
        call.call
      end
      k.send(:private, meth) if was_private
    rescue StandardError => e
      PokeAccess.write_marker("wrap #{cname}##{meth}: #{e.message}\n")
    end

    # Logs the FIRST swallowed body failure per key to the marker, so a method renamed inside a body becomes
    # visible instead of permanent silence. Deduped: a per-frame body that throws every frame writes one line.
    def self.log_body_failure(key, e)
      return if @body_logged.include?(key)
      @body_logged << key
      PokeAccess.write_marker("hook body #{key}: #{PokeAccess.format_error(e)}\n")
    end

    # Runs a hook body, swallowing exceptions so a throwing reader never breaks the game (logged once,
    # see log_body_failure).
    def self.run_body(key)
      yield
    rescue StandardError => e
      log_body_failure(key, e)
    end

    # A unique marker key per hook REGISTRATION (not per method), so when two hooks wrap the same cname#meth
    # (e.g. Game_Player#update from both audio3d and locator) a logged failure of one does not dedup-silence
    # a failure of the other.
    def self.next_key(cname, meth)
      @reg_seq += 1
      "#{cname}##{meth}@#{@reg_seq}"
    end

    # Runs body before the original, so it can speak before the original blocks. Yields (instance, args).
    # The original runs UNGUARDED: the body already spoke, so nothing it owns is at risk, and a modal loop
    # it wraps can still drive its own announcing hooks. opts as in wrap.
    def self.before_hook(cname, meth, opts = {}, &body)
      key = next_key(cname, meth)
      wrap(cname, meth, opts) { |inst, nxt, args| run_body(key) { body.call(inst, args) }; nxt.call }
    end

    # Runs body after the original, passing its result. Yields (instance, result, args). The original runs
    # under the reentrancy guard by default, so a different hooked method it calls cannot consume this
    # hook's dedup first.
    # param opts :hook_container when the method DELEGATES the announcement to hooks it drives (see
    #   nested_other?), which then runs the original unguarded; :optional as in wrap
    def self.after_hook(cname, meth, opts = {}, &body)
      key = next_key(cname, meth)
      container = opts[:hook_container]
      wrap(cname, meth, opts) do |inst, nxt, args|
        r = container ? nxt.call : guarded(meth) { nxt.call }
        run_body(key) { body.call(inst, r, args) }
        r
      end
    end

    # An after-hook for a per-frame DRIVER: a method the engine calls every frame that can host a whole
    # nested modal loop. Runs the original unguarded, like hook_container, and the body after, so a poller
    # reading post-update state has no lag. A poller and not an announcing container, hence its own name.
    # Yields (instance, args): a poller has no use for the return value.
    def self.frame_hook(cname, meth, &body)
      after_hook(cname, meth, :hook_container => true) { |inst, _r, args| body.call(inst, args) }
    end

    # Speaks a screen's opening summary, QUEUED: an opening read must never cut the transition click or a
    # line already playing, and only navigation readers interrupt. The block yields the scene and returns
    # the text, cleaned before speaking; nil or empty stays silent.
    # param meth the scene's opener, :pbStartScene by default
    # param opts :timing => :before for an opener that BLOCKS in its own loop, where an after-hook would
    #   only speak on close; :optional and :hook_container pass through
    def self.read_on_open(cname, meth = :pbStartScene, opts = {}, &blk)
      if opts[:timing] == :before
        before_hook(cname, meth, opts) do |scene, _args|
          t = blk.call(scene)
          PokeAccess.speak(PokeAccess.clean(t.to_s), false) if t && !t.to_s.empty?
        end
      else
        after_hook(cname, meth, opts) do |scene, _ret, _args|
          t = blk.call(scene)
          PokeAccess.speak(PokeAccess.clean(t.to_s), false) if t && !t.to_s.empty?
        end
      end
    end

    # Wraps a method with full control of the call. Yields (instance, call_next, args) and returns the
    # result. call_next takes no arguments and replays the chain with the caller's own; mutate the args array
    # in place to change what the original receives. The body is NOT swallowed -- its first failure is logged
    # and re-raised -- because it may legitimately choose not to run the original. opts as in wrap.
    def self.around_hook(cname, meth, opts = {}, &body)
      key = next_key(cname, meth)
      wrap(cname, meth, opts) do |inst, nxt, args|
        begin
          body.call(inst, nxt, args)
        rescue StandardError => e
          PokeAccess::Hooks.log_body_failure(key, e)
          raise e
        end
      end
    end

    # The declared REPLACEMENTS: what override() has installed, as "Target.meth (tag)" strings. The diag
    # prints this list, so steamrolling a core reader is never invisible to whoever edits the core -- the
    # gap that once let a profile's silent module-reopen shadow a core reader unnoticed.
    def self.overrides; @overrides ||= []; end

    # REPLACES a method, declaring the intent where a module reopen would be silent. The target is either a
    # mod module whose singleton method a profile substitutes, or a game class whose instance method it
    # replaces. Yields (receiver, original, args), original being a lambda that runs the replaced
    # implementation: call it to wrap instead of substitute. Around semantics, so failures are re-raised.
    # Every installation is listed by the diag, and a second override receives the first as its original.
    # param opts :tag names the owner in that listing; :optional as in wrap
    #
    # A name every class answers on its singleton (:name, :to_s) counts as a singleton method only when the
    # target defines it itself; otherwise the instance method is meant.
    def self.override(target, meth, opts = {}, &body)
      mod = target.is_a?(Module) ? target : PokeAccess.const_at(target)
      label = target.is_a?(Module) ? target.name.to_s : target.to_s
      if mod.nil?
        return if opts[:optional]
        @missing << "#{label}##{meth}" unless @missing.include?("#{label}##{meth}")
        return
      end
      meta = (class << mod; self; end)
      sing = meta.method_defined?(meth) || meta.private_method_defined?(meth)
      inst = mod.method_defined?(meth) || mod.private_method_defined?(meth)
      sing = false if sing && inst && ((meta.instance_method(meth).owner rescue nil) != meta)
      if sing
        seq = (overrides.length + 1)
        ali = "#{meth}__pa_override_#{seq}".to_sym
        meta.send(:alias_method, ali, meth)
        key = "override #{label}.#{meth}"
        meta.send(:define_method, meth) do |*args, &blk|
          begin
            body.call(mod, lambda { send(ali, *args, &blk) }, args)
          rescue StandardError => e
            PokeAccess::Hooks.log_body_failure(key, e)
            raise e
          end
        end
      elsif inst
        around_hook(label, meth, opts) { |receiver, nxt, args| body.call(receiver, nxt, args) }
      else
        return if opts[:optional]
        @missing << "#{label}##{meth}" unless @missing.include?("#{label}##{meth}")
        return
      end
      overrides << "#{label}.#{meth}#{opts[:tag] ? " (#{opts[:tag]})" : ""}"
    rescue StandardError => e
      PokeAccess.write_marker("override #{label}##{meth}: #{e.message}\n")
    end

    # Global/kernel functions a wrap found NOWHERE, neither on Kernel's singleton nor on Object. Informative
    # and not the typo list: an absent kernel function is usually legitimate variance between games, but a
    # typo in a function name has nowhere else to show up.
    def self.fn_absent; @fn_absent ||= []; end

    # Records a function name every wrapper declined to bind (see fn_absent).
    def self.note_fn_absent(name)
      fn_absent << name.to_s unless fn_absent.include?(name.to_s)
    end

    # The bodies hooked onto each wrapped function, keyed "name|timing". Held here rather than closed over
    # by the wrapper, because the wrapper is installed ONCE per function and two readers wanting the same
    # one is ordinary -- a pause menu and a glossary both want pbFadeOutIn.
    def self.fn_bodies; @fn_bodies ||= {}; end

    def self.add_fn_body(name, timing, body)
      (fn_bodies["#{name}|#{timing}"] ||= []).push(body)
    end

    # Runs the before/after bodies for a function. Each is swallowed and logged once on its own, so one
    # broken reader cannot take the others down with it, nor the game's function.
    def self.run_fn_bodies(name, timing, tag, args, result)
      list = fn_bodies["#{name}|#{timing}"]
      return if list.nil?
      list.each do |b|
        begin; b.call(args, result); rescue StandardError => e; PokeAccess.log_once(tag, e); end
      end
    end

    # The one installer behind wrap_global and wrap_kernel: defines the wrapper for sym on receiver and
    # delegates to the ali alias. :before and :after bodies chain, each swallowed and logged once, because a
    # reader bug must not crash the game's function. :around gets (args, call_next), keeps control and is
    # NOT swallowed, the same contract as around_hook. Only the FIRST :around runs.
    #
    # The :after bodies sit in an ensure because these functions are given BLOCKS, and a `return` inside the
    # caller's block unwinds straight through this wrapper. Menus written as `pbFadeOutIn { ...; return }`
    # are that shape. An exception is not the same case: $! is set only while one propagates, and there the
    # bodies stay out of the way.
    def self.define_fn_wrapper(receiver, sym, ali, tag, name)
      receiver.send(:define_method, sym) do |*args, &blk|
        PokeAccess::Hooks.run_fn_bodies(name, :before, tag, args, nil)
        r = nil
        begin
          around = PokeAccess::Hooks.fn_bodies["#{name}|around"]
          if around && !around.empty?
            begin
              r = around[0].call(args, lambda { send(ali, *args, &blk) })
            rescue StandardError => e
              PokeAccess::Hooks.log_body_failure("fn #{tag}", e)
              raise e
            end
          else
            r = send(ali, *args, &blk)
          end
        ensure
          PokeAccess::Hooks.run_fn_bodies(name, :after, tag, args, r) if $!.nil?
        end
        r
      end
    end

    # Wraps a top-level (Object instance) method -- a global Essentials function such as pbDisplayMail --
    # that the class hooks cannot reach. timing :before/:after/:around, see define_fn_wrapper for each
    # mode's contract. A missing function is recorded in fn_absent and skipped; already wrapped is a no-op.
    def self.wrap_global(name, tag, timing = :after, &body)
      sym = name.to_sym
      ali = "#{name}__pa".to_sym
      unless Object.private_method_defined?(sym) || Object.method_defined?(sym)
        note_fn_absent(name)
        return
      end
      add_fn_body(name, timing, body)
      return if Object.private_method_defined?(ali) || Object.method_defined?(ali)
      Object.send(:alias_method, ali, sym)
      define_fn_wrapper(Object, sym, ali, "global_#{name}", name)
      Object.send(:private, sym, ali)
    rescue StandardError => e
      PokeAccess.write_marker("#{tag}: #{e.message}\n")
    end

    # Wraps a function defined either as a Kernel singleton (the gen-6 style) or as a top-level Object method
    # (the modern one), which varies by game for the same name. Tries the singleton first and falls back to
    # wrap_global. Same timing modes as wrap_global.
    def self.wrap_kernel(name, tag, timing = :before, &body)
      sym = name.to_sym
      if Kernel.respond_to?(sym)
        ali = "#{name}__pa".to_sym
        sc = (class << Kernel; self; end)
        add_fn_body(name, timing, body)
        return if sc.method_defined?(ali) || sc.private_method_defined?(ali)
        sc.send(:alias_method, ali, sym)
        define_fn_wrapper(sc, sym, ali, "kernel_#{name}", name)
      else
        wrap_global(name, tag, timing, &body)
      end
    rescue StandardError => e
      PokeAccess.write_marker("#{tag}: #{e.message}\n")
    end
  end
end
