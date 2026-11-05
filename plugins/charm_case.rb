# Charms Case (CharmCase_Scene, opened by the Charm Case item): a list of the charms with no text for their state but a
# picture, which ends in the rows the plugin adds after them (Nature, Elemental, Wishing, Close Case). Each row with
# whether it is on; the info key gets the item its description box shows, and the count the screen paints in its corner
# is said as it opens and as it changes.
module PokeAccess
  module CharmCase
    # The rows drawItem counts back from the end of the list, as [Nature Charm's place, Elemental Charms' place].
    def self.tail_places(wishing, elements, nature)
      return [4, 3] if wishing && elements && nature
      taken = wishing ? 1 : 0
      ele = elements ? 2 + taken : 2
      taken += 1 if elements
      [nature ? 2 + taken : 2, ele]
    end

    # The row drawItem paints at index i: an added row by its name, a charm by its name and state.
    def self.entry(win, i)
      count = win.itemCount
      return close_row if i == count - 1
      wishing = activeCharm?(:WISHINGCHARM)
      elements = $player.elementCharmlist.length >= 1
      nature = activeCharm?(:NATURECHARM)
      return added_row(:WISHINGCHARM, _INTL("Wishing Charm")) if i == count - 2 && wishing
      nat, ele = tail_places(wishing, elements, nature)
      return added_row(:ELEMENTCHARM, _INTL("Elemental Charms")) if i == count - ele && elements
      return added_row(:NATURECHARM, _INTL("Nature Charm")) if i == count - nat && nature
      charm_row(win, win.instance_variable_get(:@stock)[i])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The closing row, kept for the info key with what the description box shows for it.
    def self.close_row
      text = _INTL("Close Case")
      PokeAccess::Info.set_info(:text, text, text)
      text
    end

    # A row the plugin adds, kept for the info key with the item its description box shows.
    def self.added_row(item, text)
      PokeAccess::Info.set_info(:item, item, text)
      text
    end

    # A charm by its name, on or off as its picture shows, kept for the info key with the item.
    def self.charm_row(win, item)
      return nil if item.nil?
      name = win.instance_variable_get(:@adapter).getDisplayName(item)
      line = "#{name}, #{PokeAccess::I18n.t($player.activeCharm?(item) ? :val_on : :val_off)}"
      PokeAccess::Info.set_info(:item, item, line)
      line
    end

    # The count in the corner ("Active Charms: 2/3"), as the screen writes it.
    def self.count_text(scene)
      box = PokeAccess.sprite(scene, "CharmCount")
      return nil unless box && (box.visible rescue false)
      PokeAccess.clean((box.text rescue "").to_s).gsub(/\s+/, " ")
    end

    # The count as the screen opens, noted so that only a change is said again.
    def self.opening_count(scene)
      count = count_text(scene)
      PokeAccess::Cursor.store(scene, :charm_count, count)
      count
    end

    # After a repaint: the focused row kept current for the info key, with the count beside it, as a charm toggled under
    # a still cursor changes both with no new read.
    def self.refreshed(scene)
      win = PokeAccess.sprite(scene, "itemwindow")
      entry(win, win.index) if win && win.index && win.index >= 0
      PokeAccess::Info.add_to_row(count_text(scene), :charm_count)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Each frame of the scene's loop: a new count, queued; this comes after the message a toggle shows, whose modal loop
    # runs none of these frames.
    def self.watch_count(scene)
      count = count_text(scene)
      PokeAccess::Cursor.announce(scene, :charm_count, count, false) { count } if count
    end
  end
end

PokeAccess::Menus.def_extractor("Window_CharmCase") { |win, i| PokeAccess::CharmCase.entry(win, i) }
PokeAccess::Hooks.read_on_open("CharmCase_Scene", :pbStartCharmScene, :optional => true) do |scene|
  PokeAccess::CharmCase.opening_count(scene)
end
PokeAccess::Hooks.after_hook("CharmCase_Scene", :pbRefresh, :optional => true) do |scene, _r, _a|
  PokeAccess::CharmCase.refreshed(scene)
end
PokeAccess::Hooks.before_hook("CharmCase_Scene", :update, :optional => true) do |scene, _a|
  PokeAccess::CharmCase.watch_count(scene)
end
PokeAccess::Hooks.clear_info_on("CharmCase_Scene", :pbEndCharmScene)
