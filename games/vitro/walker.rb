# Vitro's Walker (WalkerScene, 0382_Walker UI, the Pokegear's link with the phone app, listed only under $DEBUG for now; its other
# calls are the game's messages): every screen starts at title_bar, paints with text, fit_text and wrap, lists its options with
# option_list and ends at hint_bar, whose A and B are not the keys it reads. What a screen paints is said when it changes, then the
# option under the cursor; the QR is an image, whose code the screen also paints as text.
module PokeAccess
  module VitroWalker
    # Starts a screen's text at its title.
    def self.titled(scene, text)
      scene.instance_variable_set(:@access_walker_lines, [PokeAccess.clean(text.to_s)])
      scene.instance_variable_set(:@access_walker_option, nil)
    end

    # Adds a painted line to the screen in hand.
    def self.painted(scene, text)
      lines = PokeAccess.ivar(scene, :@access_walker_lines)
      lines.push(PokeAccess.clean(text.to_s)) if lines
    end

    # The option list's row under the cursor, for the end of the paint.
    def self.option(scene, items, index)
      row = items[index]
      return unless row
      line = PokeAccess::Verbosity.list_entry(PokeAccess.clean(row[0].to_s), index + 1, items.length)
      scene.instance_variable_set(:@access_walker_option, line)
    end

    # The screen is painted: its text when it changed, then the option when it moved; the info key keeps them.
    def self.finished(scene)
      lines = (PokeAccess.ivar(scene, :@access_walker_lines) || []).reject { |l| l.empty? }
      option = PokeAccess.ivar(scene, :@access_walker_option)
      text = PokeAccess.sentences(lines)
      PokeAccess::Cursor.announce(scene, :vitro_walker_text, text, false) { text }
      PokeAccess::Cursor.announce(scene, :vitro_walker_option, option, true, false) { option } if option
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([text, option]), option || text)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  after("WalkerScene", :title_bar, :optional => true) { |s, _r, a| PokeAccess::VitroWalker.titled(s, a[0]) }
  after("WalkerScene", :text, :optional => true) { |s, _r, a| PokeAccess::VitroWalker.painted(s, a[0]) }
  after("WalkerScene", :fit_text, :optional => true) { |s, _r, a| PokeAccess::VitroWalker.painted(s, a[0]) }
  after("WalkerScene", :wrap, :optional => true) { |s, _r, a| PokeAccess::VitroWalker.painted(s, a[0]) }
  after("WalkerScene", :option_list, :optional => true) { |s, _r, a| PokeAccess::VitroWalker.option(s, a[3], a[4]) }
  after("WalkerScene", :hint_bar, :optional => true) { |s, _r, _a| PokeAccess::VitroWalker.finished(s) }
  after("WalkerScene", :busy, :optional => true) { |_s, _r, a| PokeAccess.speak_clean(a[0].to_s, false) }
  # choose runs again as each entry returns: the option under the cursor is said again.
  before("WalkerScene", :choose, :optional => true) { |s, _a| PokeAccess::Cursor.reset(s, :vitro_walker_option) }
  clear_info_on("WalkerScene", :dispose)
end
