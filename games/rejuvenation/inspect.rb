module PokeAccess
  # Rejuvenation's Inspect report (pbShowBattleStats, read by core InspectRV) paints types and statuses as icons: the
  # rows Typing, Added, Jurisdiction, Reflected and Shadow end in <icon=typeX> marks, and a status row carries an
  # <img=...statusX>. They are worded in each row and in the whole report on the info key. Ctrl's team preview is the
  # game's own ttsPartyPreview, relayed.
  module RejuvInspect
    TYPE_RUN = /(?:<icon=type(\w+)>\s*)+/
    TYPE_ICON = /<icon=type(\w+)>/
    STATUS_ICON = /<img=[^>]*status(\w+)>/

    # The name of a type icon's type, through the game's getTypeName.
    def self.type_word(type)
      PokeAccess::DataRV.type_name(type.to_sym) || type.capitalize
    end

    # A report row with a run of type icons as their names, a list, and a status icon as the status's word; the rest of
    # its markup cleaned.
    def self.worded(row)
      t = row.to_s.gsub(TYPE_RUN) { |run| " #{run.scan(TYPE_ICON).flatten.map { |ty| type_word(ty) }.join(', ')} " }
      t = t.gsub(STATUS_ICON) { " #{PokeAccess::DataRV.status_name($1.to_sym)} " }
      PokeAccess.clean(t)
    end

    # The row under the cursor, worded.
    def self.row(win, i)
      cmds = win.instance_variable_get(:@commands)
      (cmds.is_a?(Array) && cmds[i]) ? worded(cmds[i]) : nil
    end

    # The whole report for the info key: the message above the list, then each row worded.
    def self.report_text(msgwindow, rows)
      head = (msgwindow.text rescue nil)
      PokeAccess.sentences([head].concat(Array(rows)).map { |r| worded(r) })
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  screen_reader("Window_AdvancedCommandPokemon_NoPageScroll") { |win, i| PokeAccess::RejuvInspect.row(win, i) }

  override("PokeAccess::InspectRV", :report_text) do |_mod, _original, args|
    PokeAccess::RejuvInspect.report_text(args[0], args[1])
  end

  kernel("ttsPartyPreview", :around) { |_args, nxt| PokeAccess::OwnVoiceRV.relayed { nxt.call } }
end
