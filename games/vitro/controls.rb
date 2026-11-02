# Vitro's controls screen (ControlsDisplayScene, 0284_PScreen_Controls, shown in the intro by clControlScreen): two pages, turned
# with left and right, that draw each key as a picture beside the line it explains. Each line is said after its keys. The log
# line draws an F, but what opens the log is Input::R (0350_Text Log), whose key is the one said.
module PokeAccess
  module VitroControls
    # Each key's picture as [button, the letter it stands for], or the i18n key of a key with no button of the game's.
    KEYS = { "helpArrowKeys" => :vitro_key_arrows, "helpCkey" => [:c, "C"], "helpSpacekey" => :vitro_key_space,
             "helpXkey" => [:b, "X"], "helpTabkey" => :vitro_key_tab, "helpZkey" => [:a, "Z"],
             "helpShiftkey" => :vitro_key_shift, "helpF3key" => [:f3, "F3"], "helpF4key" => [:f4, "F4"],
             "helpF5key" => [:f5, "F5"], "helpQkey" => [:l, "Q"], "helpFkey" => [:r, "W"], "helpAltkey" => [:alt, "Alt"],
             "helpMkey" => [:vitro_map, "M"] }

    # The name a key's picture stands for, or nil for a picture of no key.
    def self.key_name(path)
      key = KEYS[File.basename(path.to_s)]
      return nil unless key
      key.is_a?(Array) ? PokeAccess::KeyHints.key(key[0], key[1]) : PokeAccess::I18n.t(key)
    end

    # The page's lines top to bottom, each after the keys drawn nearest to it.
    # param pairs what the page painted, as PaintCapture.take_pairs gives it
    # param icons the pictures it drew, as PaintCapture.icon_rows gives them
    def self.lines(pairs, icons)
      rows = pairs.select { |r| r[3].is_a?(Numeric) }.sort_by { |r| r[3] }
      rows.map do |r|
        near = icons.select { |i| rows.min_by { |o| (o[3] - i[2]).abs }.equal?(r) }
        keys = near.map { |i| key_name(i[0]) }.compact
        keys.empty? ? PokeAccess.clean(r[0]) : "#{keys.join(', ')}: #{PokeAccess.clean(r[0])}"
      end
    end

    # Runs a page's paint and says it, the first queued and each turn cutting in; the info key keeps it.
    def self.page(scene, id)
      pairs = nil
      icons = PokeAccess::PaintCapture.icon_rows { pairs = PokeAccess::PaintCapture.sample { yield } }
      text = PokeAccess.sentences(lines(pairs, icons) + [PokeAccess::Verbosity.position((id || 0) + 1, ControlsDisplayScene::PAGES)])
      PokeAccess::Info.set_info(:text, text)
      PokeAccess::Cursor.announce(scene, :vitro_controls, id || 0, true, false) { text }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  around("ControlsDisplayScene", :drawPage, :optional => true) do |scene, nxt, args|
    ret = nil
    PokeAccess::VitroControls.page(scene, args[0]) { ret = nxt.call }
    ret
  end
  clear_info_on("ControlsDisplayScene", :pbEndScene)
end
