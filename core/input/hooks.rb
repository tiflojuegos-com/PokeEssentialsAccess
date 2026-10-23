module PokeAccess
  # Hook helpers. Several hooks may wrap the same method: each registers a middleware and they chain
  # (an onion) around the original, so a new feature can never silently disable an existing hook.
  module Hooks
    @chains = {}
    @missing = []
    @unbound = []
    @body_logged = []
    @reg_seq = 0
    @active = []
    @suppressed = []
    @bound = []

    # Runs install, which puts a wrapper over owner's meth, and keeps it to run again (given true) should the game's
    # scripts replace that wrapper: an F12 reset evaluates them anew (see rebind).
    def self.keep_bound(owner, meth, &install)
      install.call(false)
      @bound.push([owner, meth, owner.instance_method(meth), install])
    end

    # Puts back each wrapper the game's scripts replaced since it was installed, the game's new method becoming the
    # one it calls; a wrapper still in place is left alone. Answers how many it put back.
    def self.rebind
      @bound.inject(0) do |n, row|
        now = (row[0].instance_method(row[1]) rescue nil)
        next n if now.nil? || now == row[2]
        begin
          row[3].call(true)
          row[2] = row[0].instance_method(row[1])
          n + 1
        rescue StandardError => e
          PokeAccess.write_marker("rebind #{row[0]}##{row[1]}: #{e.message}\n")
          n
        end
      end
    end

    # After the game's scripts ran again (an F12 reset): puts back the wrappers they replaced and drops the caches
    # kept for the game that was. Answers how many wrappers it put back.
    def self.after_reset
      n = rebind
      (PokeAccess::Caches.reset_all rescue nil)
      PokeAccess.write_marker("game reset: #{n} wrappers put back\n")
      n
    end

    # Reentrancy guard: true inside a guarded original (an after_hook's) for a hooked call with a different name,
    # whose hooks are then skipped so they cannot consume the outer's dedup; the same name passes (super).
    # Containers (hook_container) and frame_hook drivers run their original unguarded.
    def self.nested_other?(meth)
      !@active.empty? && @active.last != meth
    end

    # Records a dropped hook as "outer>inner" for the diagnostic, deduped and capped at 40; often correct, so the
    # list is evidence, not a fault.
    def self.note_suppressed(inner)
      outer = @active.last
      pair = "#{outer}>#{inner}"
      return if @suppressed.include?(pair) || @suppressed.length >= 40
      @suppressed.push(pair)
    end

    # The outer>inner pairs the guard has dropped this session (see note_suppressed).
    def self.suppressed; @suppressed; end

    # The class whose hooked method ran most recently, which tells the silence watch the screen even inside a
    # blocking loop that never becomes $scene.
    def self.note_screen(cname); @screen = cname; end
    def self.screen; @screen; end

    # Runs an after-hook's original with meth pushed on the active stack, popped even if the original raises.
    def self.guarded(meth)
      @active.push(meth)
      begin
        yield
      ensure
        @active.pop
      end
    end

    # Bindings whose class exists but whose method does not, almost always a typo (an absent class is not
    # recorded); boot writes them to a marker.
    def self.missing; @missing; end

    # Hook groups that bound to none of their class-name spellings (see variants): absent from one spelling is
    # normal, from all of them a bug in the mod.
    def self.unbound; @unbound; end

    # Registers a hook on every spelling a class takes across games (the block binds one and answers whether it took),
    # skipping a sub- or superclass of one already bound; returns the names bound and records an empty group as unbound.
    # param label how to name the group in the report, defaulting to the first spelling
    def self.variants(names, meth, label = nil)
      bound_classes = []
      hit = ancestors_first(names).select do |cname|
        k = PokeAccess.const_at(cname)
        next false if k && bound_classes.any? { |b| (k <= b || b <= k) rescue false }
        took = yield(cname) ? true : false
        bound_classes.push(k) if took && k
        took
      end
      if hit.empty?
        tag = "#{label || names.first}##{meth}"
        @unbound.push(tag) unless @unbound.include?(tag) || @unbound.length >= 40
      end
      hit
    end

    # The spellings with every ancestor ahead of its descendants, so the class that owns the method binds and its
    # empty alias subclass is the one skipped.
    def self.ancestors_first(names)
      classes = names.map { |n| PokeAccess.const_at(n) }
      order = (0...names.length).sort_by do |i|
        k = classes[i]
        depth = k ? classes.select { |o| o && o != k && (k < o rescue false) }.length : 0
        [depth, i]
      end
      order.map { |i| names[i] }
    end

    # Chains a middleware around an instance method, yielding (instance, call_next, args), and answers whether it
    # registered. The alias is named per class, so wrapping a parent and then its overriding child keeps both.
    # param opts :optional when the method is legitimately absent in some games (kept out of @missing)
    def self.wrap(cname, meth, opts = {}, &mw)
      k = PokeAccess.const_at(cname)
      return false if k.nil?
      unless k.method_defined?(meth) || k.private_method_defined?(meth)
        return false if opts[:optional]
        @missing << "#{cname}##{meth}" unless @missing.include?("#{cname}##{meth}")
        return false
      end
      key = "#{cname}##{meth}"
      fresh = !@chains.key?(key)
      (@chains[key] ||= []).push(mw)
      return true unless fresh
      orig = "#{meth}__pa_orig_#{cname.gsub(/[^a-zA-Z0-9]/, '_')}".to_sym
      kept = (k.instance_methods(false) + k.private_instance_methods(false)).map { |m| m.to_sym }.include?(orig)
      chains = @chains
      keep_bound(k, meth) do |again|
        was_private = k.private_method_defined?(meth)
        keep_original(k, meth, orig) if again || !kept
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
        pass_keywords(k, meth)
        k.send(:private, meth) if was_private
      end
      bound = true
      true
    rescue StandardError => e
      @chains.delete(key) if fresh && !bound
      PokeAccess.write_marker("wrap #{cname}##{meth}: #{e.message}\n")
      false
    end

    # Keeps owner's meth under ali for the wrapper about to replace it: an alias, or, when a module prepended to owner
    # overrides meth (Ruby 2+), the method beneath that module, since an alias would copy the module's, whose super
    # then lands back in the wrapper endlessly (stack level too deep).
    def self.keep_original(owner, meth, ali)
      beneath = beneath_prepends(owner, meth)
      return owner.send(:alias_method, ali, meth) if beneath.nil?
      raise "#{meth} exists only in a module prepended to #{owner}" if beneath == false
      owner.send(:define_method, ali, beneath)
      owner.send(:private, ali) if owner.private_method_defined?(meth)
    end

    # The method a call to owner's meth reaches past the modules prepended to owner; nil when none overrides it (or
    # the Ruby has no prepend, or cannot walk past one), false when nothing lies beneath them.
    def self.beneath_prepends(owner, meth)
      anc = owner.ancestors
      at = anc.index(owner)
      return nil if at.nil? || at == 0
      um = owner.instance_method(meth)
      return nil unless (anc.index(um.owner) || at) < at
      um = um.super_method while um && (anc.index(um.owner) || at) < at
      um || false
    rescue NameError
      nil
    end

    # Marks a wrapper whose *args splat stands in for the original's parameters so keyword arguments reach the
    # original as keywords (Ruby 3 would pass them on as one positional Hash). No-op on 1.8.7, which has neither.
    def self.pass_keywords(owner, meth)
      owner.send(:ruby2_keywords, meth) if owner.respond_to?(:ruby2_keywords, true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Logs the first body failure per key to the marker; a body that throws every frame writes one line.
    def self.log_body_failure(key, e)
      return if @body_logged.include?(key)
      @body_logged << key
      PokeAccess.write_marker("hook body #{key}: #{PokeAccess.format_error(e)}\n")
    end

    # Runs a hook body, swallowing (and logging once) its exceptions so a throwing reader never breaks the game.
    def self.run_body(key)
      yield
    rescue StandardError => e
      PokeAccess.swallowed(e)
      log_body_failure(key, e)
    end

    # A marker key per hook registration, not per method, so two hooks on one method log their failures apart.
    def self.next_key(cname, meth)
      @reg_seq += 1
      "#{cname}##{meth}@#{@reg_seq}"
    end

    # Runs body before the original, yielding (instance, args); the original runs unguarded. opts as in wrap.
    def self.before_hook(cname, meth, opts = {}, &body)
      key = next_key(cname, meth)
      wrap(cname, meth, opts) { |inst, nxt, args| run_body(key) { body.call(inst, args) }; nxt.call }
    end

    # Runs body after the original, yielding (instance, result, args); the original runs under the reentrancy guard.
    # param opts :hook_container runs it unguarded, for a method whose driven hooks announce; :optional as in wrap
    def self.after_hook(cname, meth, opts = {}, &body)
      key = next_key(cname, meth)
      container = opts[:hook_container]
      wrap(cname, meth, opts) do |inst, nxt, args|
        r = container ? nxt.call : guarded(meth) { nxt.call }
        run_body(key) { body.call(inst, r, args) }
        r
      end
    end

    # An after-hook for a per-frame driver, which can host a whole nested modal loop: the original runs unguarded
    # and the body after it, yielding (instance, args).
    def self.frame_hook(cname, meth, &body)
      after_hook(cname, meth, :hook_container => true) { |inst, _r, args| body.call(inst, args) }
    end

    # Speaks, queued and cleaned, the text the block returns for the scene as it opens; nil or empty stays silent.
    # param meth the scene's opener, :pbStartScene by default
    # param opts :timing => :before for an opener that blocks in its own loop; also :optional, :hook_container
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

    # Wraps a method with full control of the call, yielding (instance, call_next, args); call_next takes no
    # arguments (mutate args in place to change them). A failing body is logged once and re-raised. opts as in wrap.
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

    # What override() has installed, as "Target.meth (tag)" strings, listed by the diag.
    def self.overrides; @overrides ||= []; end

    # Replaces a mod module's singleton method or a game class's instance method, yielding (receiver, original, args);
    # failures re-raise. A second override of a singleton gets the first as its original; on an instance method they
    # chain as in wrap, the first registered outermost. A name every class answers (:name, :to_s) is a singleton only
    # when the target defines it itself; the label is Module#name (FieldMoves.name takes a move).
    # param opts :tag names the owner in the diag's listing; :optional as in wrap
    def self.override(target, meth, opts = {}, &body)
      mod = target.is_a?(Module) ? target : PokeAccess.const_at(target)
      label = target.is_a?(Module) ? Module.instance_method(:name).bind(target).call.to_s : target.to_s
      return note_missing_override(label, meth, opts) if mod.nil?
      meta = (class << mod; self; end)
      sing = meta.method_defined?(meth) || meta.private_method_defined?(meth)
      inst = mod.method_defined?(meth) || mod.private_method_defined?(meth)
      sing = false if sing && inst && ((meta.instance_method(meth).owner rescue nil) != meta)
      if sing
        override_singleton(mod, meta, meth, label, body)
      elsif inst
        return nil unless around_hook(label, meth, opts) { |receiver, nxt, args| body.call(receiver, nxt, args) }
      else
        return note_missing_override(label, meth, opts)
      end
      overrides << "#{label}.#{meth}#{opts[:tag] ? " (#{opts[:tag]})" : ""}"
    rescue StandardError => e
      PokeAccess.write_marker("override #{label}##{meth}: #{e.message}\n")
    end

    # Replaces a singleton method in place, keeping the original under a numbered alias for the body's lambda;
    # failures are logged and re-raised.
    def self.override_singleton(mod, meta, meth, label, body)
      ali = "#{meth}__pa_override_#{overrides.length + 1}".to_sym
      key = "override #{label}.#{meth}"
      keep_bound(meta, meth) do |_again|
        keep_original(meta, meth, ali)
        meta.send(:define_method, meth) do |*args, &blk|
          begin
            body.call(mod, lambda { send(ali, *args, &blk) }, args)
          rescue StandardError => e
            PokeAccess::Hooks.log_body_failure(key, e)
            raise e
          end
        end
        pass_keywords(meta, meth)
      end
    end

    # Files an override whose target or method does not exist, unless it was declared :optional.
    def self.note_missing_override(label, meth, opts)
      return nil if opts[:optional]
      @missing << "#{label}##{meth}" unless @missing.include?("#{label}##{meth}")
      nil
    end

    # Global/kernel functions a wrap found nowhere (usually cross-game variance, or a typo).
    def self.fn_absent; @fn_absent ||= []; end

    # Records a function name every wrapper declined to bind (see fn_absent).
    def self.note_fn_absent(name)
      fn_absent << name.to_s unless fn_absent.include?(name.to_s)
    end

    # The bodies hooked onto each wrapped function, keyed "name|timing", all run by its one wrapper.
    def self.fn_bodies; @fn_bodies ||= {}; end

    def self.add_fn_body(name, timing, body)
      (fn_bodies["#{name}|#{timing}"] ||= []).push(body)
    end

    # Runs a function's before or after bodies, each swallowed and logged once on its own.
    def self.run_fn_bodies(name, timing, tag, args, result)
      list = fn_bodies["#{name}|#{timing}"]
      return if list.nil?
      list.each do |b|
        begin; b.call(args, result); rescue StandardError => e; PokeAccess.log_once(tag, e); end
      end
    end

    # Defines the wrapper for sym on receiver (behind wrap_global, wrap_kernel, wrap_singleton), delegating to ali.
    # :before/:after bodies are swallowed; :around ones get (args, call_next), nest first-registered outermost and
    # re-raise. :after runs in an ensure (a `return` in the caller's block unwinds through here), skipped on raise.
    def self.define_fn_wrapper(receiver, sym, ali, tag, name)
      receiver.send(:define_method, sym) do |*args, &blk|
        PokeAccess::Hooks.run_fn_bodies(name, :before, tag, args, nil)
        r = nil
        begin
          around = PokeAccess::Hooks.fn_bodies["#{name}|around"]
          if around && !around.empty?
            begin
              call = lambda { send(ali, *args, &blk) }
              around.reverse_each do |w|
                nxt = call
                call = lambda { w.call(args, nxt) }
              end
              r = call.call
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
      pass_keywords(receiver, sym)
    end

    # Wraps a top-level (Object) function such as pbDisplayMail; timing :before/:after/:around, as in
    # define_fn_wrapper. A missing function goes to fn_absent; a second wrap only adds its body. The wrapper keeps
    # the function's visibility, since a game may call a public one as Kernel.x.
    def self.wrap_global(name, tag, timing = :after, &body)
      sym = name.to_sym
      was_private = Object.private_method_defined?(sym)
      unless was_private || Object.method_defined?(sym)
        note_fn_absent(name)
        return
      end
      ali = "#{name}__pa".to_sym
      add_fn_body(name, timing, body)
      return if Object.private_method_defined?(ali) || Object.method_defined?(ali)
      keep_bound(Object, sym) do |_again|
        hidden = Object.private_method_defined?(sym)
        keep_original(Object, sym, ali)
        define_fn_wrapper(Object, sym, ali, "global_#{name}", name)
        Object.send(:private, ali)
        Object.send(hidden ? :private : :public, sym)
      end
    rescue StandardError => e
      PokeAccess.write_marker("#{tag}: #{e.message}\n")
    end

    # True when Kernel's own singleton defines the function (the gen-6 style); respond_to? would also say yes to
    # anything public on Object.
    def self.kernel_owns?(sym)
      sc = (class << Kernel; self; end)
      (sc.instance_methods(false) + sc.private_instance_methods(false)).map { |m| m.to_sym }.include?(sym)
    end

    # Wraps a function defined as a Kernel singleton (gen-6), else as a top-level Object method (wrap_global).
    def self.wrap_kernel(name, tag, timing = :before, &body)
      sym = name.to_sym
      if kernel_owns?(sym)
        ali = "#{name}__pa".to_sym
        sc = (class << Kernel; self; end)
        add_fn_body(name, timing, body)
        return if sc.method_defined?(ali) || sc.private_method_defined?(ali)
        keep_bound(sc, sym) do |_again|
          keep_original(sc, sym, ali)
          define_fn_wrapper(sc, sym, ali, "kernel_#{name}", name)
        end
      else
        wrap_global(name, tag, timing, &body)
      end
    rescue StandardError => e
      PokeAccess.write_marker("#{tag}: #{e.message}\n")
    end

    # Wraps a game module's own singleton method (def self.x, called as Module.x) the way wrap_kernel wraps
    # Kernel's; an absent module or method goes to fn_absent.
    def self.wrap_singleton(owner, name, tag, timing = :before, &body)
      mod = PokeAccess.const_at(owner)
      sym = name.to_sym
      sc = mod ? (class << mod; self; end) : nil
      unless sc && (sc.method_defined?(sym) || sc.private_method_defined?(sym))
        note_fn_absent("#{owner}.#{name}")
        return
      end
      key = "#{owner}.#{name}"
      ali = "#{name}__pa".to_sym
      add_fn_body(key, timing, body)
      return if sc.method_defined?(ali) || sc.private_method_defined?(ali)
      keep_bound(sc, sym) do |_again|
        keep_original(sc, sym, ali)
        define_fn_wrapper(sc, sym, ali, "singleton_#{key}", key)
      end
    rescue StandardError => e
      PokeAccess.write_marker("#{tag}: #{e.message}\n")
    end
  end
end
