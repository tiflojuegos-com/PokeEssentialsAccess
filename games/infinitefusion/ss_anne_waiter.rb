# The S.S. Anne's waiter quest (switch 1091): the dining room's customers (map 17, the events that count an order in
# variable 315) show at their table whether they have ordered and been served, and each dish in the kitchen (map 29)
# shows by its look which one it is. The locator says both after the event's name, the dish named from the menu
# (variable 313) by the event's own "variable 314 = n".
module PokeAccess
  module IFWaiter
    QUEST = 1091
    MENU = 313
    ORDER = 314
    TAKEN = 315
    DINING = 17
    KITCHEN = 29

    # The command lists of an event's pages, or of its live page alone.
    def self.lists(ev, live)
      return [PokeAccess.ivar(ev, :@list)] if live
      pages = (PokeAccess.ivar(ev, :@event).pages rescue nil)
      pages.is_a?(Array) ? pages.map { |pg| (pg.list rescue nil) } : []
    end

    # The constant of the first Control Variables command on var alone with operation op (0 set, 1 add), or nil.
    def self.constant(ev, var, op, live = false)
      lists(ev, live).each do |list|
        next unless list.is_a?(Array)
        list.each do |c|
          p = (c.parameters rescue nil)
          next unless (c.code rescue 0) == 122 && p.is_a?(Array)
          return p[4] if p[0] == var && p[1] == var && p[2] == op && p[3] == 0
        end
      end
      nil
    end

    # The menu's name for dish i, or nil.
    def self.dish(i)
      menu = $game_variables[MENU]
      name = menu.is_a?(Array) && i ? menu[i.to_i] : nil
      name ? PokeAccess.clean(name.to_s) : nil
    end

    # A customer's state: waiting to order, the dish ordered, or served; nil for any other event.
    def self.customer(ev)
      return nil if constant(ev, TAKEN, 1).nil?
      return PokeAccess::I18n.t(:if_ssa_served) if $game_self_switches[[DINING, ev.id, "C"]]
      return PokeAccess::I18n.t(:if_ssa_waiting) unless $game_self_switches[[DINING, ev.id, "D"]]
      name = dish(constant(ev, ORDER, 0))
      name ? PokeAccess::I18n.t(:if_ssa_wants, :dish => name) : nil
    end

    # The words after an event's name while the quest runs: a customer's state or a kitchen dish's name.
    def self.mark(ev)
      return nil unless $game_map && $game_switches[QUEST]
      case $game_map.map_id
      when DINING then customer(ev)
      when KITCHEN then dish(constant(ev, ORDER, 0, true))
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion") do
  name_mark { |ev| PokeAccess::IFWaiter.mark(ev) }
end
