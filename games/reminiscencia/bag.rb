module PokeAccess
  # Reminiscencia's bag (PokemonBag_Scene) is a normal Window_DrawableCommand, but here the generic
  # command-window hook does not read it, so the bag stays silent. Its choose loop calls Input.update every
  # frame, so the active bag scene is registered and its item window read from a per-frame poll, reusing
  # the core bag extractor.
  module ReminBag
    @scene = nil
    @last = nil

    # Marks a bag scene as active (called around its choose loop).
    def self.watch(scene); @scene = scene; @last = nil; end

    # Stops watching (loop finished).
    def self.unwatch; @scene = nil; @last = nil; end

    # True while a bag choose loop is active. The bag opens over the pause menu, whose loop is suspended but
    # whose poll keeps running, so ReminMenu reads this to stop re-arming the menu lock while the bag is in
    # front -- which keeps the mod's own config key reachable there. The lock gates ONLY that key
    # (core/input/input.rb), never the info key.
    def self.watching?; !@scene.nil?; end

    # Reads the focused item when it changes. Dedup keys on [pocket, row] -- the PREFIX-FREE row -- and the
    # spoken line adds the pocket prefix on top: keying on the rendered text re-reads the same row the frame
    # after a pocket switch, because the prefix legitimately appears once and then goes away.
    def self.poll
      s = @scene
      return unless s
      win = PokeAccess.sprite(s, "itemwindow")
      return unless win
      idx = (win.index rescue nil)
      return if idx.nil? || idx < 0
      row = PokeAccess.clean(PokeAccess::Menus.bag_row(win, idx).to_s)
      return if row.empty?
      key = [(win.pocket rescue nil), row]
      return if key == @last
      @last = key
      PokeAccess.speak(PokeAccess.clean("#{PokeAccess::Menus.bag_prefix(win)}#{row}"), true)
      PokeAccess::Menus.mark_bag_pocket(win)
    rescue StandardError
      nil
    end
  end
end

# Hold the bag scene for the duration of its choose loop, and read the focused item each frame while it is
# open (the loop calls Input.update).
PokeAccess::SceneWatcher.wire("PokemonBag_Scene", :pbChooseItem, PokeAccess::ReminBag)

# The same scene has a SECOND blocking loop, pbCheckItem, used when the game asks the player to pick an item
# rather than to browse: pbCheckItemScreen wraps it and the give-a-berry flow calls it. It navigates exactly
# like the main loop but was not held, so that whole screen read nothing. Only the hold is registered here --
# wire above already registered the per-frame poll for this reader, and a second one would run it twice a
# frame for no gain. The two loops never nest, so the flat watch/unwatch pair is enough.
PokeAccess::Game.define("reminiscencia") do
  around("PokemonBag_Scene", :pbCheckItem, :optional => true) do |scene, call_next, _a|
    PokeAccess::ReminBag.watch(scene)
    begin; call_next.call; ensure; PokeAccess::ReminBag.unwatch; end
  end
end

# This game's bag-watcher section of the diagnostic dump (was hardcoded in the core diag before the
# register_diag_section primitive existed).
PokeAccess::Game.define("reminiscencia") do
  diag_section(:reminbag) do |o|
    rb = PokeAccess::ReminBag
    k = PokeAccess::Keys
    s = PokeAccess.ivar(rb, :@scene)
    o.push("reminbag: watching=#{!s.nil?} last=#{k.dv { rb.instance_variable_get(:@last).inspect }}")
    unless s.nil?
      win = PokeAccess.sprite(s, "itemwindow")
      o.push("  itemwindow=#{win ? win.class : 'nil'} idx=#{k.dv { win.index }} pocket=#{k.dv { win.pocket }} adapter=#{k.dv { win.instance_variable_get(:@adapter).class }}")
      o.push("  focused_text=#{k.dv { PokeAccess::Menus.focused_text(win) }.inspect[0, 160]}") if win
    end
  end
end
