module PokeAccess
  # The blessing chooser's legend (PickBlessing#drawMaintext, as it opens and after each reset): the coins it paints,
  # and while key hints are said each action beside the key picture drawn on its row, as the player has that key.
  module ReminBlessings
    # The button each legend picture stands for, with the letter it shows: A is the game's own raw key.
    KEYS = { "A" => [:game_a, "A"], "Z" => [:a, "Z"], "C" => [:c, "C"] }

    # The legend's rows top to bottom: plain rows as painted, a row with a key picture on it as "key: action".
    # param pairs the rows drawMaintext painted (PaintCapture.take_pairs)
    # param icons the pictures it drew (PaintCapture.icon_rows)
    def self.legend(pairs, icons)
      keys = []
      (icons || []).each do |path, _x, y|
        k = KEYS[File.basename(path.to_s, ".*")]
        keys.push([y.to_i, PokeAccess::KeyHints.key(k[0], k[1])]) if k
      end
      plain = []
      hints = []
      (pairs || []).sort_by { |r| [r[3].to_i, r[2].to_i] }.each do |t, _s, _x, y|
        text = PokeAccess.clean(t.to_s)
        next if text.empty?
        key = keys.detect { |ky, _n| (y.to_i - ky).abs <= 8 }
        key ? hints.push(PokeAccess::I18n.t(:rem_key_action, :key => key[1], :action => text)) : plain.push(text)
      end
      plain.concat(hints) if PokeAccess::Verbosity.hints?
      PokeAccess.sentences(plain)
    end

    # Says the legend once the first card has been read (a reset repaints it after its cards), else keeps it for the
    # card reader to say after the opening card.
    def self.note(scene, text)
      return if text.nil? || text.empty?
      if PokeAccess.ivar(scene, :@access_bless_read)
        PokeAccess.speak(text, false)
      else
        scene.instance_variable_set(:@access_bless_legend, text)
      end
    end

    # After a card is read: marks the chooser as read and says a legend still waiting from the opening.
    def self.card_read(scene)
      scene.instance_variable_set(:@access_bless_read, true)
      legend = PokeAccess.ivar(scene, :@access_bless_legend)
      return unless legend
      scene.instance_variable_set(:@access_bless_legend, nil)
      PokeAccess.speak(legend, false)
    end
  end
end

# Reminiscencia's blessing chooser (PickBlessing, 1 of 3 cards): the focused card on each updateCursor and swapCard
# (a re-roll), from BLESSINGS_HASH[@blessings[i]]: [0] category 0..3, [1] rarity, [3] description.
PokeAccess::Game.define("reminiscencia") do
  # Category 0..3 spoken label, defined by the game's own comments (item/buff/mechanics/healing).
  cat_key = lambda do |c|
    { 0 => :rem_bless_item, 1 => :rem_bless_power, 2 => :rem_bless_mechanic, 3 => :rem_bless_heal }[c]
  end

  read = lambda do |scene|
    idx  = PokeAccess.ivar(scene, :@index)
    list = PokeAccess.ivar(scene, :@blessings)
    next unless list.is_a?(Array) && idx && idx >= 0 && idx < list.length
    next unless PokeAccess::Cursor.changed?(scene, :bless, idx)
    data = (BLESSINGS_HASH[list[idx]] rescue nil)
    next unless data.is_a?(Array)
    ck   = cat_key.call(data[0])
    cat  = ck ? PokeAccess::I18n.t(ck) : ""
    rar  = data[1].is_a?(Integer) ? PokeAccess::I18n.t(:bless_rarity, :n => data[1] + 1) : ""
    desc = PokeAccess.clean((_INTL(data[3].to_s) rescue data[3].to_s))
    parts = [[cat, :full], [rar, :medium], [desc, :brief]]
    PokeAccess.speak(PokeAccess::Verbosity.info_line(:rem_blessing, parts, ". "), true)
    PokeAccess::ReminBlessings.card_read(scene)
  end

  after("PickBlessing", :updateCursor) { |scene, _r, _a| read.call(scene) }
  after("PickBlessing", :swapCard) do |scene, _r, _a|
    PokeAccess::Cursor.reset(scene, :bless)
    read.call(scene)
  end
  around("PickBlessing", :drawMaintext, :optional => true) do |scene, nxt, _a|
    icons = nil
    ret = nil
    pairs = PokeAccess::PaintCapture.sample { icons = PokeAccess::PaintCapture.icon_rows { ret = nxt.call } }
    PokeAccess::ReminBlessings.note(scene, PokeAccess::ReminBlessings.legend(pairs, icons))
    ret
  end
end

PokeAccess::Verbosity.define_reading(:rem_blessing, :vb_rem_blessing, :vbh_rem_blessing)
