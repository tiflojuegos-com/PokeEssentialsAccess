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

    # Reentrancy guard. The game is single-threaded, so a module stack of the method names whose ORIGINAL is
    # currently running is enough: an ATOMIC after_hook pushes around its original, and wrap's dispatcher skips
    # a nested hooked call whose method name DIFFERS from the one on top. This stops an after-hook whose
    # original synchronously calls a DIFFERENT hooked method (e.g. v22 set_party_index -> refresh) from letting
    # the inner hook speak and consume the outer's dedup: the OUTER after-hook, running once the original
    # returns, is the authoritative announcer. A nested call of the SAME method name is allowed through, so an
    # overriding child that reaches its hooked parent via super still fires both hooks (the documented onion).
    #
    # The guard is correct ONLY for atomic announcers (methods whose own body is the voice). Two kinds of hook
    # must run their original UNGUARDED or they silence the very readers that do the talking:
    #   - a CONTAINER (`hook_container: true`): a modal loop or scene opener that DELEGATES the announcement to
    #     hooked methods it drives internally -- the battle command phase (pbShowCommands/pbCommandMenu drive
    #     CommandMenuDisplay#index= and FightMenuDisplay#setIndex), scene openers (pbScene/pbStartScene/main
    #     drive the pokedex drawPage, the summary drawPageOne, the party panel selected=, the map readers).
    #   - a per-frame DRIVER (`frame_hook`): a method the engine calls every frame that CAN synchronously host
    #     an entire nested modal loop. Game_Player#update is the case that forced this: in gen-6 stepping onto
    #     grass launches the wild battle from INSIDE Game_Player#update (Scene_Map#update -> $game_player.update
    #     -> encounter -> the whole battle loop), so guarding it pins :update on the stack for the entire fight
    #     and every battle reader -- messages, command menu, moves -- is skipped as nested_other?. A trainer
    #     battle runs from the map interpreter, not the player, so it was unaffected: the bug read as "wild
    #     battles are silent, trainer battles read". frame_hook is the poller-shaped alias of hook_container.
    # Default is atomic (guarded), so a hook that itself says nothing keeps the safe behaviour. before_hook
    # bodies always run before the original (so they never compete for a dedup) and never guard their original.
    def self.nested_other?(meth)
      !@active.empty? && @active.last != meth
    end

    # Records that the guard just dropped a hook, as "outer -> inner". Suppression is INVISIBLE by design --
    # the reader simply does not speak -- so a hook wrongly registered on a container silences whatever it
    # drives with no error, no log and no failing test; the only symptom is a screen that went quiet, which
    # is exactly what a blind player cannot debug. The diagnostic reports this list, so one play session
    # names every place it happens. Suppression is often CORRECT (the outer hook is the announcer), so this
    # is evidence to read, not a fault: what matters is a pair here whose outer says nothing.
    # Capped and deduped: it must never grow with playtime.
    def self.note_suppressed(inner)
      outer = @active.last
      pair = "#{outer}>#{inner}"
      return if @suppressed.include?(pair) || @suppressed.length >= 40
      @suppressed.push(pair)
    end

    # The outer>inner pairs the guard has dropped this session (see note_suppressed).
    def self.suppressed; @suppressed; end

    # The class whose hooked method ran most recently. It is the only cheap answer to "which screen is the
    # player on" that survives the case that matters: a screen running its own blocking loop is never
    # assigned to $scene, so $scene still says Scene_Map while the player is deep inside a minigame. Set
    # from the wrapper, which every hooked call goes through, and read by the silence watch.
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

    # Registers a middleware around an instance method, chaining with any others already on it. The
    # saved-original alias is named per class and the guard checks methods defined ON the class only,
    # so hooking a parent then a child that overrides the same method does not bypass the child's logic.
    # Yields (instance, call_next, args); call call_next to run the rest of the chain.
    # opts[:optional] declares the METHOD legitimately absent on some games (a plugin variant, a fork's
    # rename): the bind is skipped silently instead of landing in @missing -- which thereby keeps its
    # exact meaning of "this method SHOULD exist here and does not" (a likely typo). Before this flag the
    # repo had four local reimplementations of the same skip (Engine.has? gates, method_defined? loops,
    # a helper in battle_v22); an absent CLASS was always silent and stays so.
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

    # Logs the FIRST swallowed body failure per key to the marker -- a method renamed inside a body
    # (otherwise permanent, undiagnosable silence on that game) becomes visible. Deduped, so a per-frame
    # body that throws every frame writes one line, not thousands. Shared by run_body (swallow) and the
    # around paths (log then re-raise).
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

    # Runs body before the original (to speak before it blocks). Yields (instance, args). The original runs
    # UNGUARDED so a modal loop or scene opener it wraps (pbScene, pbStartScene, main) can still drive its
    # nested announcing hooks; the body already spoke before the original, so nothing it owns is at risk.
    # opts[:optional] as in wrap.
    def self.before_hook(cname, meth, opts = {}, &body)
      key = next_key(cname, meth)
      wrap(cname, meth, opts) { |inst, nxt, args| run_body(key) { body.call(inst, args) }; nxt.call }
    end

    # Runs body after the original, passing its result. Yields (instance, result, args). By default the
    # original runs under the reentrancy guard, so a DIFFERENT hooked method it calls internally is not
    # re-announced and cannot consume this hook's dedup before the body speaks. Pass hook_container: true when
    # the method is a modal loop or scene opener that DELEGATES the announcement to hooked methods it drives
    # internally (see nested_other?): the original then runs UNGUARDED so those nested readers still speak.
    # opts[:optional] as in wrap (a legitimately absent method binds nothing and logs nothing).
    def self.after_hook(cname, meth, opts = {}, &body)
      key = next_key(cname, meth)
      container = opts[:hook_container]
      wrap(cname, meth, opts) do |inst, nxt, args|
        r = container ? nxt.call : guarded(meth) { nxt.call }
        run_body(key) { body.call(inst, r, args) }
        r
      end
    end

    # An after-hook for a per-frame DRIVER -- a method the engine calls every frame that can synchronously host
    # a whole nested modal loop (Game_Player#update, which in gen-6 runs an entire wild battle inside itself).
    # Runs the original UNGUARDED (like hook_container) so readers driven inside that nested loop still speak,
    # and runs the body AFTER so a poller reading the post-update frame state (the player's new tile for the
    # spatial audio) has no lag. Semantically a poller, not an announcing container, so it gets its own name.
    # Yields (instance, args); a per-frame poller has no use for the original's return value. 1.8.7-safe.
    def self.frame_hook(cname, meth, &body)
      after_hook(cname, meth, :hook_container => true) { |inst, _r, args| body.call(inst, args) }
    end

    # Speaks a screen's opening summary: hooks the scene's opener (meth, default :pbStartScene) and speaks
    # the block's text QUEUED -- an opening read must never interrupt, so it cannot cut the transition
    # click or a line already being spoken; only navigation readers interrupt. The block yields the scene
    # and returns the text (nil/empty stays silent); it is cleaned before speaking. By default the text is
    # read AFTER the opener (the panel is drawn); pass :timing => :before for openers that BLOCK in their
    # own loop (e.g. a card screen paging inside its opener), where an after-hook would only speak on close. Other opts (:optional,
    # :hook_container) pass through to the underlying hook.
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

    # Wraps a method with full control of the call. Yields (instance, call_next, args); returns the result.
    # call_next replays the chain with the caller's ORIGINAL arguments (it takes none); to change what the
    # original receives, mutate the args array in place before calling call_next. The body keeps control of
    # call_next, so it is NOT swallowed; its first failure is logged then re-raised (preserving around's
    # semantics -- it may legitimately choose not to run the original). opts[:optional] as in wrap.
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

    # REPLACES a method, declaring the intent (unlike a silent module reopen): the target is either a mod
    # module whose singleton method a profile wants to substitute (MoveRelearnerGen6.detail) or a game
    # class name whose instance method must be replaced. The body receives (receiver, original, args) --
    # receiver is the module or instance, original a lambda running the replaced implementation (call it
    # to wrap instead of substitute; around semantics, so failures are logged and re-raised, never
    # swallowed). Each installation is recorded in overrides and listed by the diag. A second override on
    # the same method receives the FIRST override as its original (last one wins, both stay listed).
    # opts[:tag] names the owner in the listing (the DSL passes the profile); opts[:optional] as in wrap.
    # A name every class answers on its singleton (:name, :to_s, inherited from Module) only counts as a
    # singleton method when the target defines it itself; otherwise the instance method is what is meant.
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

    # Global/kernel functions a wrap looked for and found NOWHERE (neither Kernel singleton nor Object).
    # Informative, NOT the typo list: a kernel function absent on a game is usually legitimate variance
    # (pbDisplayText exists only on a few fangames), so it must not read as a fault -- but a typo'd
    # function name used to be invisible forever, and this line in the diag is where it shows up.
    def self.fn_absent; @fn_absent ||= []; end

    # Records a function name every wrapper declined to bind (see fn_absent).
    def self.note_fn_absent(name)
      fn_absent << name.to_s unless fn_absent.include?(name.to_s)
    end

    # The one installer behind wrap_global and wrap_kernel: defines the wrapper for sym on receiver (Object,
    # or Kernel's singleton class), delegating to the ali alias. timing :before/:after bodies are swallowed
    # and logged once (a reader bug must not crash the game's function); :around gets (args, call_next),
    # keeps control of the call and is NOT swallowed -- its first failure is logged then re-raised, the same
    # contract as around_hook (it may legitimately choose not to run the original). 1.8.7-safe.
    def self.define_fn_wrapper(receiver, sym, ali, tag, timing, body)
      receiver.send(:define_method, sym) do |*args, &blk|
        case timing
        when :around
          begin
            body.call(args, lambda { send(ali, *args, &blk) })
          rescue StandardError => e
            PokeAccess::Hooks.log_body_failure("fn #{tag}", e)
            raise e
          end
        when :after
          r = send(ali, *args, &blk)
          begin; body.call(args, r); rescue StandardError => e; PokeAccess.log_once(tag, e); end
          r
        else
          begin; body.call(args, nil); rescue StandardError => e; PokeAccess.log_once(tag, e); end
          send(ali, *args, &blk)
        end
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
      return if Object.private_method_defined?(ali) || Object.method_defined?(ali)
      Object.send(:alias_method, ali, sym)
      define_fn_wrapper(Object, sym, ali, "global_#{name}", timing, body)
      Object.send(:private, sym, ali)
    rescue StandardError => e
      PokeAccess.write_marker("#{tag}: #{e.message}\n")
    end

    # Wraps a function that may be defined either as a Kernel singleton (def Kernel.foo, the gen-6 style) or
    # as a top-level Object method (def foo, the modern style) -- pbShowCommandsWithHelp is one such, varying
    # by game. Tries the Kernel singleton first, else falls back to wrap_global for the Object form (which
    # records a nowhere-defined name in fn_absent). Same timing modes as wrap_global. 1.8.7-safe.
    def self.wrap_kernel(name, tag, timing = :before, &body)
      sym = name.to_sym
      if Kernel.respond_to?(sym)
        ali = "#{name}__pa".to_sym
        sc = (class << Kernel; self; end)
        return if sc.method_defined?(ali) || sc.private_method_defined?(ali)
        sc.send(:alias_method, ali, sym)
        define_fn_wrapper(sc, sym, ali, "kernel_#{name}", timing, body)
      else
        wrap_global(name, tag, timing, &body)
      end
    rescue StandardError => e
      PokeAccess.write_marker("#{tag}: #{e.message}\n")
    end
  end
end
