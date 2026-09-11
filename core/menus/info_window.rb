module PokeAccess
  # Screens that keep a standing INFORMATION window: a sprite the scene writes with text= and repaints as the
  # cursor moves, holding what the list rows do not say. A global text= listener would talk over dialogue, so
  # the windows are NAMED: a watch is one (scene class, sprite key) pair, read whenever its text changes while
  # that scene runs, deduped through Cursor on the scene. A named window that is never found is recorded and
  # printed by the diagnostic, like an unbound hook group.
  module InfoWindow
    # The lifecycle shapes a scene opens with, tried in order. The first is Essentials'; `start` is the
    # monolithic one half the games give these screens. A scene whose opener is its own (Fire Ash's swap
    # screen has two, pbStartRentScene and pbStartSwapScene, and no pbStartScene at all) names it from its
    # profile, because that name is the game's and not the engine's.
    OPENERS = [:pbStartScene, :start]

    # And the close. A screen with one mode per entrance names both ends after the mode (the mart is
    # pbStartBuyScene/pbEndBuyScene in all fifteen games, with no pbStartScene at all) and declares its own.
    CLOSERS = [:pbEndScene]

    @watches = []
    @bound = {}
    @live = nil
    @silent = []
    @unentered = []

    # The registered watches, as [scene class, sprite key, dedup slot, interrupt, optional] rows. The class
    # is the resolved object, not its name: tick walks this list every frame and must not look a constant up.
    def self.watches; @watches; end

    # The watches whose window was never there, as "Class.key". A screen declared under a key it does not
    # use is a reader that can never speak, and nothing else would ever say so.
    def self.silent; @silent; end

    # The scene classes that took no lifecycle at all: the class is there, the windows are there, and the
    # scene is simply never entered, so every watch on it is dead. Worse than a missing window, which at
    # least records itself once the screen runs -- this one leaves no trace anywhere.
    def self.unentered; @unentered; end

    # Declares a scene's information window and binds the scene's own open and close.
    # param cname the scene class, in whatever spelling the game uses
    # param key the sprite key the scene stores that window under
    # param slot a symbol naming this window's dedup state, distinct per window on a shared scene
    # param opts :interrupt to cut what is playing rather than queue; :open with this game's own opener
    #   name(s) and :close with its own close (the close is also what says the opener BUILDS the screen
    #   rather than running it); :optional for a window that belongs to one of two layouts of the same screen
    # return whether a LIFECYCLE bound, not merely whether the class exists, so variants can tell
    #
    # A class this game lacks registers nothing, not even the row; the lifecycle is bound once per class, and
    # a second window on a bound class answers what the first call answered.
    def self.watch(cname, key, slot, opts = {})
      k = PokeAccess.const_at(cname)
      return false unless k
      @watches.push([k, key.to_s, slot, opts[:interrupt] ? true : false, opts[:optional] ? true : false])
      return @bound[cname] if @bound.has_key?(cname)
      @bound[cname] = false
      closers = [opts[:close]].flatten.compact.map { |n| n.to_sym }
      closers = CLOSERS if closers.empty?
      closers.each do |meth|
        PokeAccess::Hooks.after_hook(cname, meth, :hook_container => true, :optional => true) do |_s, _r, _a|
          PokeAccess::InfoWindow.leave
        end
      end
      bound = bind_openers(cname, k, [opts[:open]].flatten.compact.map { |n| n.to_sym } + OPENERS, closers)
      @bound[cname] = bound
      @unentered.push(cname) unless bound
      bound
    end

    # Binds the scene's open to every candidate method it has (a screen with one opener per mode is entered
    # from either). Two shapes, told apart by what the class has: an opener that BUILDS the screen and
    # returns is entered after it and left by the close hook; one that RUNS the whole screen (`start`) is
    # wrapped. Both lifecycle hooks are CONTAINERS: guarding the opener skipped the pbRefresh hook the dex
    # screens announce from, and nine screens opened silent.
    def self.bind_openers(cname, k, names, closers = CLOSERS)
      closes = closers.any? { |c| (k.method_defined?(c) rescue false) }
      bound = false
      names.each do |meth|
        took = if closes || meth == :pbStartScene
                 PokeAccess::Hooks.after_hook(cname, meth, :hook_container => true, :optional => true) do |scene, _r, _a|
                   PokeAccess::InfoWindow.enter(scene)
                 end
               else
                 PokeAccess::Hooks.around_hook(cname, meth, :optional => true) do |scene, nxt, _a|
                   PokeAccess::InfoWindow.enter(scene)
                   begin
                     nxt.call
                   ensure
                     PokeAccess::InfoWindow.leave
                   end
                 end
               end
        bound ||= took
      end
      bound
    end

    # The scene whose windows are being watched, held over its lifetime.
    def self.enter(scene); @live = scene; @said = {}; end
    def self.leave; @live = nil; @said = {}; end
    def self.live; @live; end

    # One frame of the watch: every window of the live scene that changed since the last frame is spoken.
    # Runs off the frame poller rather than off text=, because a scene rewrites the same window several
    # times while painting one state and only the settled value is worth a line.
    def self.tick
      scene = @live
      return unless scene
      @watches.each do |k, key, slot, interrupt, optional|
        next unless scene.is_a?(k)
        say(scene, key, slot, interrupt, optional)
      end
    rescue StandardError
      nil
    end

    # Speaks one watched window if its text changed. The dedup runs on the RAW text; blank text is a state
    # too, so a window cleared and rewritten with the same words speaks again. An interrupting window does
    # not interrupt its FIRST reading of a scene: on the opening frame every window is new at once and an
    # interrupt could only cut a sibling. A hidden window is skipped before the dedup, so one filled while
    # hidden is read the moment it is shown.
    def self.say(scene, key, slot, interrupt, optional = false)
      win = PokeAccess.sprite(scene, key)
      return (optional ? nil : note_silent(scene, key)) unless win
      return if (win.visible rescue true) == false
      raw = (win.text rescue nil)
      return if raw.nil?
      return unless PokeAccess::Cursor.changed?(scene, slot, raw.to_s)
      t = PokeAccess.clean_fields(raw)
      return if t.empty?
      first = !(@said ||= {})[slot]
      @said[slot] = true
      PokeAccess.speak(t, interrupt && !first)
    rescue StandardError
      nil
    end

    # Speaks the painted pokedex header minus the focused species, which the same pbDrawTextPositions batch
    # paints on every step of the list and the list reader has just said. The species is identified from the
    # screen's own icon sprite, not guessed from position. Stands down where the header windows exist.
    def self.say_dex_header(scene)
      rows = PokeAccess::PaintCapture.take(:dex_header) || []
      return if PokeAccess.sprite(scene, "seen")
      focus = dex_focus_name(scene)
      rows = rows.reject { |r| r.to_s.strip == focus } if focus
      t = PokeAccess::PaintCapture.text(rows)
      return if t.to_s.strip.empty?
      return unless PokeAccess::Cursor.changed?(scene, :dex_header, t.to_s)
      PokeAccess.speak(t, false)
    rescue StandardError
      nil
    end

    # The name of the species the dex list is focused on, from the screen's own icon sprite, or nil.
    def self.dex_focus_name(scene)
      sp = (PokeAccess.sprite(scene, "pokedex").species rescue nil)
      return nil unless sp
      n = (PokeAccess::Data.species_name(sp) rescue nil)
      (n.nil? || n.to_s.empty?) ? nil : n.to_s
    rescue StandardError
      nil
    end

    # Notes a declared window the scene does not have. Capped and deduped, like the suppressed-hook list.
    # An :optional watch never lands here: the pokedex header is a window in one era and painted text in the
    # other, both readers are installed on both spellings, and a list of nine expected absences is how a real
    # one stops being noticed.
    def self.note_silent(scene, key)
      tag = "#{scene.class}.#{key}"
      return if @silent.include?(tag) || @silent.length >= 20
      @silent.push(tag)
      nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Keys.on_frame { PokeAccess::InfoWindow.tick }

# A scene that never announced its close (or announces it under another name) would leave the watch pointing
# at a dead scene, polling disposed windows every frame on the map. The map change drops it, as it drops
# every other per-screen memo.
PokeAccess::Caches.register(:info_window) { PokeAccess::InfoWindow.leave }

# The phone's two standing windows, present under both spellings of the scene. The bottom one is rewritten
# with the focused contact's map name as the cursor moves, which is the only place the screen says WHERE a
# contact is; the info one holds how many are registered and how many are waiting for a rematch, painted
# once on open. Both queue: they follow the cursor rather than answer a keypress, and the contact's own name
# is already being spoken.
PokeAccess::Hooks.variants(["PokemonPhoneScene", "PokemonPhone_Scene"], :pbStartScene, "phone_info") do |cname|
  a = PokeAccess::InfoWindow.watch(cname, "bottom", :phone_where)
  b = PokeAccess::InfoWindow.watch(cname, "info", :phone_totals)
  a || b
end

# The pokedex list header (seen, owned, search notice): some builds keep each in its own window, others paint
# it onto the overlay from pbRefresh. Both readers go on both class spellings, since the name does not tell
# the layout (Awakening is gen-6 with the modern spelling), and the paint one stands down where the windows
# exist. One group, because it is one screen.
PokeAccess::Hooks.variants(["PokemonPokedexScene", "PokemonPokedex_Scene"], :pbStartScene, "dex_header") do |cname|
  a = PokeAccess::InfoWindow.watch(cname, "seen", :dex_seen_total, :optional => true)
  b = PokeAccess::InfoWindow.watch(cname, "owned", :dex_owned_total, :optional => true)
  c = PokeAccess::InfoWindow.watch(cname, "dexname", :dex_list_name, :optional => true)
  d = PokeAccess::Hooks.around_hook(cname, :pbRefresh, :optional => true) do |scene, nxt, _a|
    PokeAccess::PaintCapture.arm(:dex_header)
    begin
      nxt.call
    ensure
      PokeAccess::InfoWindow.say_dex_header(scene)
    end
  end
  a || b || c || d
end
