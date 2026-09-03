module PokeAccess
  # Strips Essentials control codes and HTML-like tags for natural speech. The player-name code (\PN)
  # is substituted first, before the generic \X stripper would eat it. Control bytes \x00-\x1f (e.g. \1
  # "wait for input", \2 wait-time) are removed too: they are not speakable, and leaving them in makes the
  # same line differ from its non-paused twin and slip past say_dialogue's dedup -> double battle messages.
  #
  # <br> becomes a space before the generic tag stripper runs. It is a LINE BREAK, so deleting it outright
  # glued the words on either side into one -- battle messages built as "{1} used<br>{2}" came out as one
  # unpronounceable word. The other tags (<b>, <c2=...>, <r>) are formatting and rightly leave no gap.
  # Markup-separated panel text (<r>, <br>, the <ac> centring pair) as one cleaned line with ", " between
  # the fields: clean alone deletes those tags and glues the map name to the first label.
  FIELD_TAGS = /<\s*\/?\s*(r|br|ac)\s*\/?\s*>/i

  def self.clean_fields(text)
    t = clean(text.to_s.gsub(FIELD_TAGS, ", ")).to_s.strip
    t.gsub(/(,\s*)+/, ", ").sub(/\A,\s*/, "").sub(/,\s*\z/, "")
  end

  def self.clean(message)
    t = message.to_s.dup
    t.gsub!(/\r?\n/, " ")
    pname = (($player.name rescue nil) || ($Trainer.name rescue nil) || "").to_s
    t.gsub!(/\\[Pp][Nn]/) { pname } rescue nil
    t.gsub!(/\\[Vv]\[(\d+)\]/) { $game_variables ? $game_variables[$1.to_i].to_s : "" } rescue nil
    t.gsub!(/\\[Nn]/, " ")
    t.gsub!(/\\[Cc]\[\d+\]/, "")
    t.gsub!(/\\[Tt][Gg]\[([^\]]*)\]/) { "#{$1}: " } rescue nil
    t.gsub!(/\\[A-Za-z]+\[[^\]]*\]/, "")
    t.gsub!(/\\[A-Za-z]+/, "")
    t.gsub!(/\\[.!|^<>~\\]/, "")
    t.gsub!(/<\s*br\s*\/?\s*>/i, " ")
    t.gsub!(/<\/?[A-Za-z][^>]*>/, "")
    t.gsub!(/\|/, " ")
    t.gsub!(/[\x00-\x1f]/, " ")
    t.gsub!(/\s+/, " ")
    t.strip
  end
end
