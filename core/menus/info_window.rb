module PokeAccess
  # Standing information windows, named per screen: a watch is a (scene class, sprite key) pair, read when its text
  # changes while that scene runs, deduped on the scene. A named window never found is recorded for the diagnostic.
  module InfoWindow
    # The openers tried on every scene: Essentials' pbStartScene and the monolithic start; others come via :open.
    OPENERS = [:pbStartScene, :start]

    # The default close; a screen with its own (the mart's pbEndBuyScene) declares it via :close.
    CLOSERS = [:pbEndScene]

    @watches = []
    @bound = {}
    @live = nil
    @silent = []
    @unentered = []

    # The registered watches: [scene class, sprite key, dedup slot, interrupt, optional, reading] rows, the class
    # resolved rather than named, since tick walks them every frame.
    def self.watches; @watches; end

    # The watches whose window was never there, as "Class.key" (for the diagnostic).
    def self.silent; @silent; end

    # The scene classes on which no opener bound, so every watch on them is dead (for the diagnostic).
    def self.unentered; @unentered; end

    # Declares a scene's information window and binds its open and close once per class; true when an opener
    # bound (a class the game lacks registers nothing).
    # param slot this window's dedup symbol, distinct per window on a shared scene
    # param opts :interrupt (cut, not queue); :open, :close (the game's own; a close means the opener builds the
    #   screen); :optional (one of two layouts); :reading [reading, level] (a focused-row window, said from
    #   that level up and always part of Ctrl+T)
    def self.watch(cname, key, slot, opts = {})
      k = PokeAccess.const_at(cname)
      return false unless k
      @watches.push([k, key.to_s, slot, opts[:interrupt] ? true : false, opts[:optional] ? true : false, opts[:reading]])
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

    # Binds every candidate opener the class has: entered after one that builds the screen (the class has a close, or
    # it is pbStartScene), as a container so its inner hooks still fire; wrapped around one that runs the screen.
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

    # One frame: speaks each live-scene window that changed (a focused-row one only from its level up). Polled per
    # frame, not on text=, since a scene rewrites a window several times while painting one state.
    def self.tick
      scene = @live
      return unless scene
      @watches.each do |k, key, slot, interrupt, optional, gate|
        next unless scene.is_a?(k)
        if gate
          to_row(scene, key, slot)
          next unless PokeAccess::Verbosity.keep?(gate[0], gate[1])
        end
        say(scene, key, slot, interrupt, optional)
      end
    rescue StandardError
      nil
    end

    # Hands a window of the focused row to what Ctrl+T says, every frame, since each new row starts it over.
    def self.to_row(scene, key, slot)
      win = PokeAccess.sprite(scene, key)
      return unless win && (win.visible rescue true) != false
      PokeAccess::Info.add_to_row(PokeAccess.clean_fields((win.text rescue nil).to_s), slot)
    rescue StandardError
      nil
    end

    # Speaks one watched window when its raw text changes (blank counts, so a rewrite after a clear speaks again),
    # minus key-hint sentences while hints are off; a hidden one waits; a window's first read per scene never cuts.
    def self.say(scene, key, slot, interrupt, optional = false)
      win = PokeAccess.sprite(scene, key)
      return (optional ? nil : note_silent(scene, key)) unless win
      return if (win.visible rescue true) == false
      raw = (win.text rescue nil)
      return if raw.nil?
      return unless PokeAccess::Cursor.changed?(scene, slot, raw.to_s)
      t = PokeAccess::KeyHints.gate_sentences(PokeAccess.clean_fields(raw))
      return if t.empty?
      first = !(@said ||= {})[slot]
      @said[slot] = true
      PokeAccess.speak(t, interrupt && !first, :menu)
    rescue StandardError
      nil
    end

    # Speaks the painted pokedex header without the focused species (named by its icon sprite) or "???" runs, which
    # the list reader says; stands down where the header windows exist.
    def self.say_dex_header(scene)
      rows = PokeAccess::PaintCapture.take(:dex_header) || []
      return if PokeAccess.sprite(scene, "seen")
      focus = dex_focus_name(scene)
      rows = rows.reject { |r| r.to_s.strip == focus || r.to_s.strip =~ /\A\?+\z/ }
      t = PokeAccess::PaintCapture.text(rows)
      return if t.to_s.strip.empty?
      return unless PokeAccess::Cursor.changed?(scene, :dex_header, t.to_s)
      PokeAccess.speak(t, false, :menu)
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

    # Notes a declared window the scene does not have (deduped, capped at 20); an :optional watch never lands here.
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

# Drops the live scene on map change, in case its close was never seen.
PokeAccess::Caches.register(:info_window) { PokeAccess::InfoWindow.leave }

# The phone's two windows (both scene spellings), queued: bottom holds the focused contact's map, info the counts
# of registered contacts and pending rematches.
PokeAccess::Hooks.variants(["PokemonPhoneScene", "PokemonPhone_Scene"], :pbStartScene, "phone_info") do |cname|
  a = PokeAccess::InfoWindow.watch(cname, "bottom", :phone_where)
  b = PokeAccess::InfoWindow.watch(cname, "info", :phone_totals)
  a || b
end

# The pokedex list header (seen, owned, list name): windows in some builds, painted from pbRefresh in others. Both
# readers go on both spellings, since the class name does not tell the layout.
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
