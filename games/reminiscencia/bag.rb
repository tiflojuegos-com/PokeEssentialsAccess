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

    # True while a bag choose loop is active. The bag opens over the pause menu (whose loop is suspended),
    # so ReminMenu reads this to stop holding the typing lock while the bag is foreground -- otherwise the
    # info key (T) stays swallowed and item descriptions never read.
    def self.watching?; !@scene.nil?; end

    # Reads the focused item when it changes. The generic Window_PokemonBag extractor already prefixes the
    # pocket name into the same line when the pocket changes ("Objetos. Llave: 3"), so dedup on the SPOKEN
    # TEXT, not on index/pocket -- the index can settle over two frames after a pocket switch, which a
    # key-based dedup would read twice (once with the prefix, once without, cutting the first off).
    def self.poll
      s = @scene
      return unless s
      win = PokeAccess.sprite(s, "itemwindow")
      return unless win
      idx = (win.index rescue nil)
      return if idx.nil? || idx < 0
      txt = PokeAccess.clean(PokeAccess::Menus.focused_text(win).to_s)
      return if txt.empty? || txt == @last
      @last = txt
      PokeAccess.speak(txt, true)
    rescue StandardError
      nil
    end
  end
end

# Hold the bag scene for the duration of its choose loop, and read the focused item each frame while it is
# open (the loop calls Input.update).
PokeAccess::SceneWatcher.wire("PokemonBag_Scene", :pbChooseItem, PokeAccess::ReminBag)

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
