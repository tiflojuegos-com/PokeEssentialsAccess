# Kyu's TextLog plugin (class Log): its update loops until the log closes, so the reader is a scene watcher polling
# each frame. Not required here: the harness loads it, and a second load reassigns its constants.

Suite.define("text log: the visible page ends at @pos - 1 and spans @lines entries") do
  saved = ($PokemonGlobal.log rescue nil)
  begin
    def $PokemonGlobal.log; @pa_log; end
    def $PokemonGlobal.log=(v); @pa_log = v; end
    $PokemonGlobal.log = [["primera linea"], ["segunda", "con dos"], ["tercera"]]
    tl = PokeAccess::TextLog
    scene = Object.new

    scene.instance_variable_set(:@pos, 2)
    scene.instance_variable_set(:@lines, 2)
    eq "the page is the two entries the paint drew", tl.page_range(scene), [0, 1]
    eq "and they come out as one spoken line", tl.page_text(scene), "primera linea. segunda con dos"

    scene.instance_variable_set(:@lines, 1)
    eq "one drawn entry is one entry read", tl.page_range(scene), [1]

    scene.instance_variable_set(:@pos, 0)
    eq "at the top there is nothing before the first entry", tl.page_range(scene), nil

    scene.instance_variable_set(:@pos, 99)
    scene.instance_variable_set(:@lines, 2)
    eq "past the end it clamps to the last entries", tl.page_range(scene), [1, 2]

    scene.instance_variable_set(:@lines, 0)
    eq "an unset line count still reads the newest entry", tl.page_range(scene), [2]

    $PokemonGlobal.log = []
    eq "an empty history shows no page", tl.page_range(scene), nil
    eq "and asking for its text is a clean nil", tl.entry_text(nil), nil
    eq "an index outside the log is nil, never a crash", tl.entry_text(7), nil
  ensure
    $PokemonGlobal.log = saved if saved
  end
end

# Kyu's Log as the game pages it: the opening page and each one reached going up are built back from the newest entry
# while they fit, each one reached going down is drawn forward while they fit, so it can hold one entry past @pos.
module TextLogPaging
  ROOM = 384 - 2 * 25

  # The entries a page built back from pos holds, oldest first (initialize and the up move).
  def self.back_page(log, pos, pad)
    total = 0
    w = 0
    out = []
    while total <= ROOM && pos - w >= 0
      total += 32 * log[pos - w].length + pad
      out.unshift(pos - w) if total <= ROOM
      w += 1
    end
    out
  end

  def self.open(scene, log, pad)
    drawn = back_page(log, log.length - 1, pad)
    scene.instance_variable_set(:@lines, drawn.length)
    scene.instance_variable_set(:@pos, log.length)
    drawn
  end

  def self.down(scene, log, pad)
    pos = scene.instance_variable_get(:@pos)
    return nil unless pos < log.length - 1
    total = 0
    w = 0
    drawn = []
    while total <= ROOM && pos + w <= log.length - 1
      h = 32 * log[pos + w].length
      drawn.push(pos + w) if total + h <= ROOM
      total += h + pad
      w += 1
    end
    scene.instance_variable_set(:@pos, pos + w - 1)
    scene.instance_variable_set(:@lines, w - 1)
    drawn
  end

  def self.up(scene, log, pad)
    pos = scene.instance_variable_get(:@pos) - scene.instance_variable_get(:@lines)
    return nil unless pos > 0
    drawn = back_page(log, pos - 1, pad)
    scene.instance_variable_set(:@lines, drawn.length)
    scene.instance_variable_set(:@pos, pos)
    drawn
  end
end

Suite.define("text log: every page the game draws is the page read, going down to the newest entry too") do
  saved = ($PokemonGlobal.log rescue nil)
  made = !Object.const_defined?(:INTERPAD)
  begin
    def $PokemonGlobal.log; @pa_log; end
    def $PokemonGlobal.log=(v); @pa_log = v; end
    sizes = [1, 2, 3, 1, 4, 2, 1, 3, 2, 1]
    log = (0...37).map { |i| (1..sizes[i % sizes.length]).map { |l| "entrada #{i} linea #{l}" } }
    $PokemonGlobal.log = log
    tl = PokeAccess::TextLog
    [4, 12].each do |pad|
      Object.const_set(:INTERPAD, pad) if pad != 4 && made
      scene = Object.new
      wrong = []
      drawn = TextLogPaging.open(scene, log, pad)
      wrong.push([:open, drawn, tl.page_range(scene)]) unless tl.page_range(scene) == drawn
      moves = [:down] * 12 + [:up] * 5 + [:down, :up, :down, :down, :up, :up, :up] + [:down] * 12
      moves.each do |m|
        page = TextLogPaging.send(m, scene, log, pad)
        next unless page
        got = tl.page_range(scene)
        wrong.push([m, page, got]) unless got == page
      end
      eq "INTERPAD #{pad}: every page read is the page drawn", wrong, []
      eq "INTERPAD #{pad}: back down at the end, the newest entry is on the page read",
         tl.page_range(scene).include?(log.length - 1), true
      Object.send(:remove_const, :INTERPAD) if Object.const_defined?(:INTERPAD) && made
    end
  ensure
    Object.send(:remove_const, :INTERPAD) if made && Object.const_defined?(:INTERPAD)
    $PokemonGlobal.log = saved if saved
  end
end

# Kyu's Log as the game pages it: the opening page and each one reached going up are built back from the newest entry
# while they fit, each one reached going down is drawn forward while they fit, so it can hold one entry past @pos.
module TextLogPaging
  ROOM = 384 - 2 * 25

  # The entries a page built back from pos holds, oldest first (initialize and the up move).
  def self.back_page(log, pos, pad)
    total = 0
    w = 0
    out = []
    while total <= ROOM && pos - w >= 0
      total += 32 * log[pos - w].length + pad
      out.unshift(pos - w) if total <= ROOM
      w += 1
    end
    out
  end

  def self.open(scene, log, pad)
    drawn = back_page(log, log.length - 1, pad)
    scene.instance_variable_set(:@lines, drawn.length)
    scene.instance_variable_set(:@pos, log.length)
    drawn
  end

  def self.down(scene, log, pad)
    pos = scene.instance_variable_get(:@pos)
    return nil unless pos < log.length - 1
    total = 0
    w = 0
    drawn = []
    while total <= ROOM && pos + w <= log.length - 1
      h = 32 * log[pos + w].length
      drawn.push(pos + w) if total + h <= ROOM
      total += h + pad
      w += 1
    end
    scene.instance_variable_set(:@pos, pos + w - 1)
    scene.instance_variable_set(:@lines, w - 1)
    drawn
  end

  def self.up(scene, log, pad)
    pos = scene.instance_variable_get(:@pos) - scene.instance_variable_get(:@lines)
    return nil unless pos > 0
    drawn = back_page(log, pos - 1, pad)
    scene.instance_variable_set(:@lines, drawn.length)
    scene.instance_variable_set(:@pos, pos)
    drawn
  end
end

Suite.define("text log: every page the game draws is the page read, going down to the newest entry too") do
  saved = ($PokemonGlobal.log rescue nil)
  made = !Object.const_defined?(:INTERPAD)
  begin
    def $PokemonGlobal.log; @pa_log; end
    def $PokemonGlobal.log=(v); @pa_log = v; end
    sizes = [1, 2, 3, 1, 4, 2, 1, 3, 2, 1]
    log = (0...37).map { |i| (1..sizes[i % sizes.length]).map { |l| "entrada #{i} linea #{l}" } }
    $PokemonGlobal.log = log
    tl = PokeAccess::TextLog
    [4, 12].each do |pad|
      Object.const_set(:INTERPAD, pad) if pad != 4 && made
      scene = Object.new
      wrong = []
      drawn = TextLogPaging.open(scene, log, pad)
      wrong.push([:open, drawn, tl.page_range(scene)]) unless tl.page_range(scene) == drawn
      moves = [:down] * 12 + [:up] * 5 + [:down, :up, :down, :down, :up, :up, :up] + [:down] * 12
      moves.each do |m|
        page = TextLogPaging.send(m, scene, log, pad)
        next unless page
        got = tl.page_range(scene)
        wrong.push([m, page, got]) unless got == page
      end
      eq "INTERPAD #{pad}: every page read is the page drawn", wrong, []
      eq "INTERPAD #{pad}: back down at the end, the newest entry is on the page read",
         tl.page_range(scene).include?(log.length - 1), true
      Object.send(:remove_const, :INTERPAD) if Object.const_defined?(:INTERPAD) && made
    end
  ensure
    Object.send(:remove_const, :INTERPAD) if made && Object.const_defined?(:INTERPAD)
    $PokemonGlobal.log = saved if saved
  end
end
