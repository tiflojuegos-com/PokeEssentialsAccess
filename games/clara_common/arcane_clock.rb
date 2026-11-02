# The arcane clock (ItemsM), a ring of gem pictures with no text: entries are [picture, label, function], the picture
# blank while the gem is missing. The focused gem is said by its label as the selector moves, the first one queued.
module PokeAccess
  module ClaraClock
    # An entry as the ring shows it: the gem's label, or that its slot is empty.
    def self.entry_text(item)
      name = PokeAccess.clean(item[1].to_s)
      item[0].to_s.empty? ? PokeAccess::I18n.t(:clara_gem_empty, :name => name) : name
    end

    # Keeps the focused entry for the info key.
    def self.publish(line)
      PokeAccess::Info.set_info(:text, line, line)
    end

    # Says the entry under the selector when it changes.
    def self.focus(menu)
      items = PokeAccess.ivar(menu, :@items)
      idx = PokeAccess.ivar(menu, :@selected_item)
      return unless items.is_a?(Array) && idx.is_a?(Integer) && items[idx].is_a?(Array)
      PokeAccess::Cursor.announce(menu, :clara_clock, idx, true, false) do
        line = PokeAccess::Verbosity.list_entry(entry_text(items[idx]), idx + 1, items.length)
        publish(line)
        line
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("clara_common") do
  after("ItemsM", :redrawSelector, :optional => true) { |menu, _r, _a| PokeAccess::ClaraClock.focus(menu) }
  clear_info_on("ItemsM", :pbEndScene)
end
