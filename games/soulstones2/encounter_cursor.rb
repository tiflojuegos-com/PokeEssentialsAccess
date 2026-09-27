# The species cursor Soulstones 2's edited Encounter List UI adds (JumpUp/JumpDown), said with its position; the
# info key keeps the species with its state. The shared reader reads each page whole. A negative @idx (JumpUp after
# a page change) marks the species from the end, as the game draws it. Action shows or hides a layer of type icons
# over the species: while shown, the cursor adds the types, and the switch itself is said.
module PokeAccess
  module SS2EncounterTypes
    # The species under the cursor as [its place on the page, species, how many the page holds], or nil.
    def self.focus(scene)
      enc = page_species(scene)
      return nil unless enc.is_a?(Array) && !enc.empty?
      idx = PokeAccess.ivar_i(scene, :@idx)
      idx += enc.length if idx < 0
      enc[idx] ? [idx, enc[idx], enc.length] : nil
    end

    # The page's species. getEncData walks every species in the game, and the frame poll asks on every frame, so the
    # list is kept while its page shows.
    def self.page_species(scene)
      index = PokeAccess.ivar(scene, :@index)
      unless @page && @page[0].equal?(scene) && @page[1] == index
        @page = [scene, index, (scene.send(:getEncData)[0] rescue nil)]
      end
      @page[2]
    end

    # Whether the type layer shows over the species at place i, read off its own icon: Action flips them all and a
    # page change hides them all, but the redraw after a Demonic Eye battle hides only those of species not caught.
    def self.shown?(scene, i)
      s = PokeAccess.sprite(scene, "type1_#{i}")
      s && (s.visible rescue false) ? true : false
    end

    # The types the layer paints over a species: its own once caught, else the ?? icon.
    def self.types(sp)
      dex = (PokeAccess::Engine.player.pokedex rescue nil)
      names = (dex && (dex.owned?(sp) rescue false)) ? (PokeAccess::Data.species_types(sp) rescue []) : []
      PokeAccess::I18n.t(:pc_types, :t => names.empty? ? PokeAccess::I18n.t(:pdx_unknown_short) : names.join(" "))
    end

    # A species as the cursor says it, its types added while the layer shows over it.
    # param i its place on the page
    # param whole true for the info key, which says the state at any level
    def self.entry(scene, i, sp, whole = false)
      t = PokeAccess::EncounterList.entry_text(sp, whole)
      shown?(scene, i) ? "#{t}, #{types(sp)}" : t
    end

    def self.hold(scene); @scene = scene; end

    def self.release(scene)
      @scene = nil
      @page = nil
      PokeAccess::Cursor.reset(scene, :ss2_enc_layer)
    end

    # From the frame poll: says the layer going up over the focused species, with its types, or down. Interrupting
    # when Action flipped it, queued behind the page when a page change took it down; a cursor move is left to the
    # cursor's own line, which already says the types or leaves them out.
    def self.poll
      scene = @scene
      return unless scene
      f = focus(scene)
      return unless f
      key = [PokeAccess.ivar(scene, :@index), f[0], shown?(scene, f[0])]
      prev = PokeAccess::Cursor.current(scene, :ss2_enc_layer)
      return unless PokeAccess::Cursor.changed?(scene, :ss2_enc_layer, key)
      return if prev.nil? || prev[2] == key[2] || (prev[0] == key[0] && prev[1] != key[1])
      on = PokeAccess::I18n.t(:ss2_enc_types_on)
      line = key[2] ? "#{on}. #{entry(scene, f[0], f[1])}" : PokeAccess::I18n.t(:ss2_enc_types_off)
      PokeAccess.speak(line, prev[0] == key[0])
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  after("EncounterList_Scene", :pbMoveDexSel, :optional => true) do |scene, _r, _a|
    ui = PokeAccess::SS2EncounterTypes
    f = ui.focus(scene)
    if f && PokeAccess::Cursor.changed?(scene, :enc_cursor, [PokeAccess.ivar(scene, :@index), f[0]])
      pos = PokeAccess::Verbosity.position(f[0] + 1, f[2])
      PokeAccess::Info.set_info(:text, ui.entry(scene, f[0], f[1], true))
      PokeAccess.speak([ui.entry(scene, f[0], f[1]), pos].compact.join(", "), true)
    end
  end

  # The list's loop, held so the frame poll can watch the type layer.
  around("EncounterList_Scene", :pbEncounter, :optional => true) do |scene, nxt, _a|
    PokeAccess::SS2EncounterTypes.hold(scene)
    begin
      nxt.call
    ensure
      PokeAccess::SS2EncounterTypes.release(scene)
    end
  end

  poll_each_frame { PokeAccess::SS2EncounterTypes.poll }
end
