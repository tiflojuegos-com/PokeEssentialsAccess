# Pokemon Reborn SWM's Item Radar Mod (both Soulstones: the second one's copy, ported to v20, runs it on steps only
# while an item is held, and keeps aUpdateRadar as it is): using the Itemfinder toggles a radar whose aUpdateRadar,
# run after every step, marks each hidden item near the player. Read as it marks them, when the set changes.
module PokeAccess
  module ItemRadar
    # How far the radar reaches from the player: it skips an item 8 columns or 6 rows away or more.
    REACH_X = 8
    REACH_Y = 6

    # The self switches of a picked-up hidden item, any of which takes it off the radar.
    TAKEN = %w[A B C D]

    # Whether a map event is a hidden item the radar marks: named HiddenItem, within its reach, none of its self
    # switches on.
    def self.marks?(event, px, py)
      return false unless (event.name rescue nil) == "HiddenItem"
      return false if (px - event.x).abs >= REACH_X || (py - event.y).abs >= REACH_Y
      mid = ($game_map.map_id rescue nil)
      TAKEN.none? { |s| ($game_self_switches[[mid, event.id, s]] rescue false) }
    end

    # The hidden items the radar marks now, nearest first.
    def self.marked
      px = $game_player.x
      py = $game_player.y
      events = ($game_map.events.values rescue []) || []
      events.select { |e| marks?(e, px, py) }.sort_by { |e| [(e.x - px).abs + (e.y - py).abs, e.id] }
    rescue StandardError
      []
    end

    # What the radar marks: how many, then the nearest one's steps and direction; or that it marks none.
    def self.text(events)
      return PokeAccess::I18n.t(:irad_none) if events.empty?
      near = PokeAccess.hidden_item_text(events.first)
      count = PokeAccess::I18n.t(:irad_marks, :n => events.length)
      near ? "#{count}. #{near}" : count
    end

    # Speaks the radar's marks, queued behind the game's own message, whenever the set it shows changes, and
    # forgets them while the radar is off, so turning it on says them again.
    def self.update(screen)
      unless PokeAccess.ivar(screen, :@aItemsFoundVisible)
        @last = nil
        return
      end
      events = marked
      key = [($game_map.map_id rescue nil), events.map { |e| e.id }.sort]
      return if key == @last
      @last = key
      PokeAccess.speak(text(events), false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("Game_Screen", :aUpdateRadar, :optional => true) do |screen, _r, _a|
  PokeAccess::ItemRadar.update(screen)
end
