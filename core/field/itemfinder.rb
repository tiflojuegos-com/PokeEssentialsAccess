module PokeAccess
  # Itemfinder/Dowsing Machine: the direction and distance to the hidden item pbClosestHiddenItem returns.

  # The spoken direction and step count to a hidden-item event, or "underfoot", or nil.
  def self.hidden_item_text(event)
    return nil unless event && $game_player
    dx = (event.x - $game_player.x); dy = (event.y - $game_player.y)
    return I18n.t(:if_underfoot) if dx == 0 && dy == 0
    parts = []
    parts.push(I18n.t(dy < 0 ? :dir_up : :dir_down)) if dy != 0
    parts.push(I18n.t(dx < 0 ? :dir_left : :dir_right)) if dx != 0
    I18n.t(:if_direction, :n => dx.abs + dy.abs, :dir => parts.join(" "))
  end

  # Announces the nearest hidden item's direction and distance.
  def self.say_hidden_item(event)
    t = hidden_item_text(event)
    speak(t, true) if t
  end
end

# pbClosestHiddenItem (top-level in both engines): announces the closest hidden item it returns.
PokeAccess::Hooks.wrap_global("pbClosestHiddenItem", "hook_itemfinder", :after) { |_args, r| PokeAccess.say_hidden_item(r) }
