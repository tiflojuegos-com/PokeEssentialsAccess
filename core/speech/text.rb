module PokeAccess
  # Game text made speakable (clean): name and money codes substituted, name-box codes turned into the speaker,
  # other codes and tags removed, <br> read as a space, entities decoded, control bytes blanked (say_dialogue's dedup
  # needs it).
  # FIELD_TAGS are the panel separators clean_fields turns into ", ".
  FIELD_TAGS = /<\s*\/?\s*(r|br|ac)\s*\/?\s*>/i

  # A panel's fields joined by ", ": separator tags and runs of commas become one, a digit-grouping comma ("3,000")
  # stays as painted.
  def self.clean_fields(text)
    t = clean(text.to_s.gsub(FIELD_TAGS, ", ")).to_s.strip.gsub(/(\d),(?=\d)/, "\\1\001")
    t.gsub(/\s*(?:,\s*)+/, ", ").sub(/\A,\s*/, "").sub(/,\s*\z/, "").tr("\001", ",")
  end

  # The bare control codes the games' message systems recognise, longest first (\pog before \pg): speaker colours
  # \b \r, gendered colours \pg \pog, window codes \wu \wm \wd \op \cl, money and points windows \G \CN \pt \ft \hs
  # \qp \apw, anil's \sh, awakening's \pksz \wshs. An unlisted one hits the generic sweep, which eats the next word.
  BARE_CODES = /\\(?:pksz|wshs|pog|apw|pg|wu|wm|wd|op|cl|cn|sh|pt|ft|hs|qp|b|r|g)/i

  # The bracketed codes that open a name box above the message: \tg (vanilla), \ta \tb and \js (awakening), \xn \dxn
  # \xna \xnb \xnc (the Mr Gela name windows, Soulstones 2).
  NAME_CODES = /\\(?:tg|ta|tb|js|dxn[abc]?|xn[abc]?)\[([^\]]*)\]/i

  # Rules a profile adds for the name a box really shows, where the game rewrites the code's name on its way to the
  # window (Reminiscencia's "???").
  @name_filters = []

  # Registers a rule. Yields the name the code carries, returns the name to speak (or nil to keep it).
  def self.register_name_filter(&blk); @name_filters.push(blk); end
  def self.name_filters; @name_filters; end

  # The speaker's name as the box paints it: the first comma-separated field (the \xn parameter is a whole list of
  # name, colours, font and position), then whatever the profile's rules make of it; a box that shows only question
  # marks (a hidden speaker's "???") is said as the word for an unknown speaker, since a screen reader drops them.
  def self.speaker_name(raw)
    nm = raw.to_s.split(",")[0].to_s.strip
    @name_filters.each do |f|
      out = (f.call(nm) rescue nil)
      nm = out.to_s if out
    end
    nm =~ /\A\?+\z/ ? PokeAccess::I18n.t(:msg_speaker_unknown) : nm
  rescue StandardError
    raw.to_s
  end

  # The five character entities the games' text drawing turns back into characters (toUnformattedText and
  # getFormattedText), in its order: &amp; last, so "&amp;quot;" stays "&quot;" as painted.
  ENTITIES = [["&lt;", "<"], ["&gt;", ">"], ["&apos;", "'"], ["&quot;", "\""], ["&amp;", "&"]]

  # The player's money for the \pm code, or "" without a player.
  def self.money_text
    who = (defined?($player) && $player) ? $player : (defined?($Trainer) ? $Trainer : nil)
    (who.money rescue nil).to_s
  end

  def self.clean(message)
    t = message.to_s.dup
    t.gsub!(/\r?\n/, " ")
    pname = (($player.name rescue nil) || ($Trainer.name rescue nil) || "").to_s
    t.gsub!(/\\[Uu][Pp][Nn]/) { pname.upcase } rescue nil
    t.gsub!(/\\[Dd][Pp][Nn]/) { pname.downcase } rescue nil
    t.gsub!(/\\[Pp][Nn]/) { pname } rescue nil
    t.gsub!(/\\[Pp][Mm]/) { money_text } rescue nil
    t.gsub!(/\\[Vv]\[(\d+)\]/) { $game_variables ? $game_variables[$1.to_i].to_s : "" } rescue nil
    t.gsub!(/\\[Cc]\[\d+\]/, "")
    t.gsub!(NAME_CODES) { "#{speaker_name($1)}: " } rescue nil
    t.gsub!(/\\[A-Za-z]{1,4}\[[^\]]*\]/, "")
    t.gsub!(/\\\[[0-9A-Fa-f]{8}\]/, "")
    t.gsub!(/\\[Nn]/, " ")
    t.gsub!(BARE_CODES, "")
    t.gsub!(/\\[A-Za-z]{1,4}(?![A-Za-z])/, "")
    t.gsub!(/\\[.!|^<>~\\1]/, "")
    t.gsub!(/\\/, "")
    t.gsub!(/<\s*br\s*\/?\s*>/i, " ")
    t.gsub!(/<\/?[A-Za-z][^>]*>/, "")
    ENTITIES.each { |ent, ch| t.gsub!(ent, ch) }
    t.gsub!(/\|/, " ")
    t.gsub!(/[\x00-\x1f]/, " ")
    t.gsub!(/\s+/, " ")
    t.strip
  end

  # Parts joined as sentences; one that already closes its own ("Teletr.") takes no second mark, nor one that
  # leads into the next (a label ending in a colon, "LISTA DE TARJETAS:"). Empty parts are left out.
  def self.sentences(parts)
    out = ""
    parts.each do |p|
      s = p.to_s.strip
      next if s.empty?
      out << (out =~ /[.!?:]\z/ ? " " : ". ") unless out.empty?
      out << s
    end
    out
  end
end
