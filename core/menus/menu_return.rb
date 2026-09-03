module PokeAccess
  # The "back from a submenu" signal shared by every menu whose entries run INLINE in its own loop (the
  # sprite-button pause menus, DP, Neo, relict's ring, reminiscencia's stack, awakening's panels): an entry
  # opens a screen, the loop carries on with the same cursor and nothing repaints the focused option, so the
  # player is back on an option they can no longer hear. The seams that close a subscreen are three engine
  # functions -- pbFadeOutIn for the screens that fade, pbMessage/pbConfirmMessage for the entries that only
  # put up a dialogue -- plus whatever a game opens bare (declared with bare / bare_fn). Each seam is a
  # nesting level and only the OUTERMOST exit fires the listeners: a message inside the bag inside the menu
  # ends with the bag on screen, and announcing the menu there talks over what the player has in front.
  # Wrapped ONCE here for every listener, where each menu used to wrap the three functions on its own.
  module MenuReturn
    @listeners = []
    @depth = 0

    # Registers a block to run on the outermost return. Each listener gates itself on its menu being open,
    # because these seams fire for everything: a map transition fades too.
    def self.on_return(&blk); @listeners.push(blk) if blk; end

    def self.enter!; @depth += 1; end

    def self.leave!
      @depth = [@depth - 1, 0].max
      fire if @depth == 0
    end

    # Forgets the nesting, on a menu's open: a subscreen that left through a throw leaves the counter high,
    # and the next real return would then be swallowed as nested.
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

    # Declares a subscreen a game opens WITHOUT any of the three seams -- a method whose call IS the screen
    # -- so returning from it counts like a fade does.
    def self.bare(cname, meth, opts = {})
      PokeAccess::Hooks.around_hook(cname, meth, opts) do |_s, nxt, _a|
        enter!
        begin
          nxt.call
        ensure
          leave!
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
