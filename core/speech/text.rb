module PokeAccess
  # Strips Essentials control codes and HTML-like tags for natural speech. The player-name and money codes
  # (\PN, \pm, \upn, \dpn) are substituted, the bracketed codes (\c[n], \l[n], \wt[n]...) and the bare ones
  # removed; the bracketed codes that open a NAME BOX become the speaker (NAME_CODES). Bare codes are matched
  # from a LIST first, since a game glues them onto the text ("\bHello!") and a greedy match ate the first
  # word; an unlisted one falls to the bounded sweep below, which eats the short word after it or leaves its
  # letters glued to a long one, which is why the list exists. Control bytes \x00-\x1f go too, or a paused
  # line slips past say_dialogue's dedup. <br> becomes a space, since it is a line break; the other tags are
  # formatting and leave no gap. FIELD_TAGS are the panel separators clean_fields turns into ", ", where
  # clean alone would glue the fields together.
  FIELD_TAGS = /<\s*\/?\s*(r|br|ac)\s*\/?\s*>/i

  def self.clean_fields(text)
    t = clean(text.to_s.gsub(FIELD_TAGS, ", ")).to_s.strip
    t.gsub(/(,\s*)+/, ", ").sub(/\A,\s*/, "").sub(/,\s*\z/, "")
  end

  # The bare (bracketless) control codes the surveyed games' message systems recognise, longest first so
  # \pog is matched whole rather than as \pg followed by an o: the speaker colours \b \r, the gendered
  # colours \pg \pog, the window codes \wu \wm \wd \op \cl, the money and points windows \G \CN \pt \ft \hs
  # \qp \apw, anil's \sh, awakening's \pksz \wshs. \PN, \pm and \n are handled on their own.
  #
  # The list has to be a LIST. A bare code that is not on it falls to the generic sweep below, which cannot
  # tell where the code ends: it eats the word that follows ("\ptSi." became "."), and where the next letter
  # is accented -- not [A-Za-z] -- it splits the word instead and the code is read out letter by letter.
  # \pt alone appears in vanilla and eight of the games.
  BARE_CODES = /\\(?:pksz|wshs|pog|apw|pg|wu|wm|wd|op|cl|cn|sh|pt|ft|hs|qp|b|r|g)/i

  # The bracketed codes that open a NAME BOX above the message. Seven spellings across the games and their
  # plugins: \tg (vanilla), \ta and \tb (awakening's second and third name boxes), \js (awakening's own NPC
  # name plugin) and \xn \dxn \xna \xnb \xnc (the Mr Gela name windows Soulstones 2 ships). All but the
  # first two were erased by the generic bracket sweep, so in those games nobody said who was speaking --
  # which on a screen whose portrait is the only other clue is the line's whole subject.
  NAME_CODES = /\\(?:tg|ta|tb|js|dxn[abc]?|xn[abc]?)\[([^\]]*)\]/i

  # Rules a PROFILE adds for the name a box really shows. The name in the code is not always the name on
  # screen: Reminiscencia hides one character behind "???" until a switch is flipped, and rewrites the
  # parameter on its way to the window (reminiscencia/0500 Messages.rb:1727). Reading the code raw told the
  # player who it was, which is the one thing that scene is withholding -- and no generic rule can know
  # that, because the condition is the game's.
  @name_filters = []

  # Registers a rule. Yields the name the code carries, returns the name to speak (or nil to keep it).
  def self.register_name_filter(&blk); @name_filters.push(blk); end
  def self.name_filters; @name_filters; end

  # The speaker's name as the box paints it: the FIRST comma-separated field, because the parameter of the
  # \xn family is a whole list (name, base colour, shadow colour, font, size, alignment, x, y, skin) and the
  # window itself takes only the first of it -- the rest was being read out as hexadecimal. Then whatever a
  # profile's rule makes of it.
  def self.speaker_name(raw)
    nm = raw.to_s.split(",")[0].to_s.strip
    @name_filters.each do |f|
      out = (f.call(nm) rescue nil)
      nm = out.to_s if out
    end
    nm
  rescue StandardError
    raw.to_s
  end

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
    t.gsub!(/\|/, " ")
    t.gsub!(/[\x00-\x1f]/, " ")
    t.gsub!(/\s+/, " ")
    t.strip
  end
end
