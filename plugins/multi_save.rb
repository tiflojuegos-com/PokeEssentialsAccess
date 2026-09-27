module PokeAccess
  # Multi Save ("Auto Multi Save" and "Multi Save"): the detail box beside the slot list (empty, or the save's date,
  # map and play time), rebuilt every frame and said queued after the slot label.
  module MultiSave
    # Says the slot's detail box, its markup-separated fields turned into pauses (clean_fields).
    def self.slot_info(scene, text)
      t = PokeAccess.clean_fields(text)
      return if t.empty?
      PokeAccess::Cursor.reset(scene, :ams_slot) if moving?
      PokeAccess::Cursor.announce(scene, :ams_slot, t, false) { t }
    rescue StandardError
      nil
    end

    # Arms or disarms the slot submenu's question: the first message window slotSelectCommands lays out is its own.
    def self.asking(on); @asking = on; end

    # Says, queued ahead of the slot list, the question the submenu opens its message window with ("Which slot to
    # save in?", each copy in its own words); only the first window laid out after asking.
    def self.question(text)
      return unless @asking
      @asking = false
      t = PokeAccess.clean(text.to_s)
      PokeAccess.speak(t, false) unless t.empty?
    rescue StandardError
      nil
    end

    # The keys the slot list moves on (a vertical Window_CommandPokemonEx that also pages with JUMPUP/JUMPDOWN).
    KEYS = [:UP, :DOWN, :JUMPUP, :JUMPDOWN]

    # Whether the cursor just moved (one of KEYS pressed this frame), which tells a new slot from a redraw, since
    # every empty slot reads alike (the index is a local of the plugin's loop).
    def self.moving?
      KEYS.any? do |name|
        k = (Input.const_get(name) rescue nil)
        k && (Input.trigger?(k) || Input.repeat?(k))
      end
    rescue StandardError
      false
    end
  end
end

# The slot submenu (slotSelectCommands, shared by every copy) resets the dedup on entry and exit, so the detail is
# read again under its question and back on the list; the question is armed to be said as its window is laid out.
PokeAccess::Hooks.around_hook("PokemonSaveScreen", :slotSelectCommands, :optional => true) do |screen, nxt, _a|
  scene = PokeAccess.ivar(screen, :@scene)
  PokeAccess::Cursor.reset(scene, :ams_slot) if scene
  PokeAccess::MultiSave.asking(true)
  begin
    nxt.call
  ensure
    PokeAccess::MultiSave.asking(false)
    PokeAccess::Cursor.reset(scene, :ams_slot) if scene
  end
end

# Every copy lays its question window out with pbBottomLeftLines as soon as it is built.
PokeAccess::Hooks.wrap_kernel("pbBottomLeftLines", "multi_save_question", :before) do |args, _r|
  PokeAccess::MultiSave.question((args[0].text rescue nil))
end

PokeAccess::Hooks.before_hook("PokemonSave_Scene", :pbUpdateSlotInfo, :optional => true) do |scene, args|
  PokeAccess::MultiSave.slot_info(scene, args[0])
end
