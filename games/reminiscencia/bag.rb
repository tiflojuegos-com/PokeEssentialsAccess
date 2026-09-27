module PokeAccess
  # Reminiscencia's bag (PokemonBag_Scene): the item window of the active scene, read each frame through the core
  # bag extractor and claimed from the generic command-window reader, which would say every row twice.
  module ReminBag
    @scene = nil
    @last = nil

    # Marks a bag scene as active (called around its choose loop) and claims its item window.
    def self.watch(scene)
      @scene = scene
      @last = nil
      PokeAccess.dedicate(PokeAccess.sprite(scene, "itemwindow"))
    end

    # Stops watching (loop finished).
    def self.unwatch; @scene = nil; @last = nil; end

    # True while a bag loop is active; ReminMenu then stops re-arming its menu lock, so the config key works here.
    def self.watching?; !@scene.nil?; end

    # The pocket of the run's rogue items, whose title paints how many the bag holds against its limit.
    SPECIAL_POCKET = 3

    # The pocket prefix due on a switch, the Special pocket's with the count its title paints under it.
    def self.pocket_prefix(win)
      pre = PokeAccess::Menus.bag_prefix(win)
      return pre if pre.empty? || (win.pocket rescue nil) != SPECIAL_POCKET
      n = ($PokemonBag.getRogueItemCount rescue nil)
      lim = ($Trainer.rogueItemLimit rescue nil)
      return pre if n.nil? || lim.nil?
      "#{pre.sub(/\.\s*\z/, '')}, #{PokeAccess::I18n.t(:list_pos, :i => n, :n => lim)}. "
    end

    # Reads the focused item when [pocket, row] changes; the key leaves out the pocket prefix, said only on a switch.
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
      PokeAccess.speak(PokeAccess.clean("#{pocket_prefix(win)}#{row}"), true)
      PokeAccess::Menus.mark_bag_pocket(win)
    rescue StandardError
      nil
    end
  end
end

# Holds the bag scene during pbChooseItem and reads its focused item each frame.
PokeAccess::SceneWatcher.wire("PokemonBag_Scene", :pbChooseItem, PokeAccess::ReminBag)

# pbCheckItem, the scene's second loop (picking an item rather than browsing): only held, since wire above already
# registered the poll; the two loops never nest.
PokeAccess::Game.define("reminiscencia") do
  around("PokemonBag_Scene", :pbCheckItem, :optional => true) do |scene, call_next, _a|
    PokeAccess::ReminBag.watch(scene)
    begin; call_next.call; ensure; PokeAccess::ReminBag.unwatch; end
  end
end

# This game's bag-watcher section of the diagnostic dump.
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
