module PokeAccess
  # Storage System Utilities (Swdfm; anil, royal, soulstones 2): the PC's multi-select rectangle and the block it
  # lifts, whose Pokemon counts are said when they change.
  module StorageUtilities
    # How many Pokemon the rectangle takes in, or nil when none is being drawn.
    def self.selected(scene)
      g = PokeAccess.ivar(scene, :@grabber)
      return nil unless g && PokeAccess.ivar(scene, :@multi) && g.holding_anything? && !g.carrying
      storage = PokeAccess.ivar(scene, :@storage)
      box = storage.currentBox
      width = (PokemonBox::BOX_WIDTH rescue 6)
      g.mons.count { |dx, dy| storage[box, g.mock_pivot + dx + dy * width] rescue nil }
    rescue StandardError
      nil
    end

    # How many Pokemon the arrow carries, or nil when it carries none. The lifted block keeps every slot
    # of the rectangle, the empty ones as a nil Pokemon, so only the filled ones count.
    def self.carried(scene)
      g = PokeAccess.ivar(scene, :@grabber)
      return nil unless g && g.carrying
      (g.carried_mons || []).count { |m| m && m[0] }
    rescue StandardError
      nil
    end

    # The rectangle's or the carried block's count when it changes, held for flush on the next frame so the slot line
    # (which interrupts) does not cut it; outside multi-select the dedup slot is let go.
    def self.poll(scene)
      sel = selected(scene)
      car = carried(scene)
      line = if car then PokeAccess::I18n.t(:su_carrying, :n => car)
             elsif sel then PokeAccess::I18n.t(:su_selected, :n => sel)
             end
      if line.nil?
        @pending = nil
        return PokeAccess::Cursor.reset(scene, :su_block)
      end
      @pending = line if PokeAccess::Cursor.changed?(scene, :su_block, line)
    end

    # From the frame poller: the count held by poll, queued behind the slot line.
    def self.flush
      line = @pending
      @pending = nil
      PokeAccess.speak(line, false) if line
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonStorageScene", :pbSetArrow, :optional => true) do |scene, _r, _a|
  PokeAccess::StorageUtilities.poll(scene)
end
PokeAccess::Keys.on_frame { PokeAccess::StorageUtilities.flush }
