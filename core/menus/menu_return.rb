module PokeAccess
  # The "back from a submenu" signal for menus whose entries run inline in their own loop, where nothing repaints the
  # focused option on return. Seams: pbFadeOutIn, pbMessage, pbConfirmMessage and any declared with bare / bare_fn;
  # they nest, and only the outermost exit fires the listeners.
  module MenuReturn
    @listeners = []
    @depth = 0

    # Registers a block for the outermost return; it must check its own menu is open, since any fade fires it.
    def self.on_return(&blk); @listeners.push(blk) if blk; end

    def self.enter!; @depth += 1; end

    # param announce false for a subscreen after which the menu closes
    def self.leave!(announce = true)
      @depth = [@depth - 1, 0].max
      fire if announce && @depth == 0
    end

    # Zeroes the nesting on a menu's open, in case a subscreen left through a throw.
    def self.reset_nesting; @depth = 0; end

    def self.fire
      @listeners.each do |l|
        begin
          l.call
        rescue StandardError => e
          PokeAccess.log_once("menu_return", e)
        end
      end
    end

    # Declares a method whose call is a whole subscreen, opened without the three seams, as a return seam.
    # param opts :closes => true when the menu closes after it: its dialogues still nest, and its end is silent
    def self.bare(cname, meth, opts = {})
      closes = opts[:closes]
      hook_opts = opts.reject { |k, _v| k == :closes }
      PokeAccess::Hooks.around_hook(cname, meth, hook_opts) do |_s, nxt, _a|
        enter!
        begin
          nxt.call
        ensure
          leave!(!closes)
        end
      end
    end

    # The same for a global function that runs a whole screen (pbQuestlog and its kind).
    def self.bare_fn(fn)
      PokeAccess::Hooks.wrap_kernel(fn, "menu_return_#{fn}", :around) do |_args, nxt|
        enter!
        begin
          nxt.call
        ensure
          leave!
        end
      end
    end
  end
end

%w[pbFadeOutIn pbMessage pbConfirmMessage].each { |fn| PokeAccess::MenuReturn.bare_fn(fn) }
