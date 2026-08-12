# Module-held dedup state outlives every screen: nothing disposes a module, so a "@last" that only ever
# fills up makes the SECOND visit silent -- the reader compares the fresh screen against a key kept from
# the previous one and concludes nothing changed. Readers shipped that way speak perfectly on every first
# visit, which is why no play session catches them; the reset path is the whole difference, so its absence
# is what this check hunts.
#
# Two rules, both heuristic, both aimed at the ABSENCE family only (a reset that restores a stale key, as
# a stack pop can, is beyond a static scan):
#   1. a file that speaks and guards on a module ivar named like dedup state (@last*/@prev*/@seen*) must
#      also assign nil to that ivar somewhere INSIDE a method. The module-body initializer does not count:
#      it runs once per process, which is exactly the lifetime being guarded against.
#   2. a Cursor call on the module-wide table (holder nil, literal slot) must have a matching
#      Cursor.reset(nil, slot) or UIV21.reset(slot) somewhere in the tree, unless the key on that same
#      line self-invalidates per screen (__id__ / object_id).
#   3. every literal speak_changed tag needs a UIV21.reset of that tag somewhere: those tags reach the
#      module-wide table through a VARIABLE slot, which rule 2 cannot see.
# Files where a missing reset IS the design carry their justification in ALLOW.
Suite.define("static/dedup: el estado de modulo tiene camino de reset") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  files = Dir[File.join(root, "{core,games,plugins}", "**", "*.rb")].sort

  # dialogue.rb: @last_say pairs with @last_say_t, a clock -- the time window is the reset.
  allow = ["core/dialogue/dialogue.rb"]

  # True when iv is assigned nil on a line inside a def (one-liner defs count; the def/end tracker keys on
  # indentation, which the formatter keeps disciplined). Module-body assignments never satisfy it.
  reset_in_method = lambda do |lines, iv|
    stack = []
    found = false
    lines.each do |l|
      if l =~ /^(\s*)def\b/
        indent = $1.length
        found = true if l =~ /@#{iv}\s*=\s*nil\b/
        stack.push(indent) unless l =~ /\bend\s*\z/
        next
      end
      if l =~ /^(\s*)end\b/ && !stack.empty? && $1.length == stack.last
        stack.pop
        next
      end
      found = true if !stack.empty? && l =~ /@#{iv}\s*=\s*nil\b/
    end
    found
  end

  offenders = []
  cursor_slots = {}
  cursor_resets = {}
  sc_tags = {}

  files.each do |path|
    rel = path[(root.length + 1)..-1].tr("\\", "/")
    src = File.read(path)
    lines = src.split("\n")

    lines.each do |l|
      if l =~ /Cursor\.(?:announce|changed\?|on_change)\(\s*nil\s*,\s*:(\w+)/
        slot = $1
        selfkey = (l =~ /__id__|object_id/) ? true : false
        prev = cursor_slots[slot]
        cursor_slots[slot] = [rel, (prev ? prev[1] : false) || selfkey]
      end
      cursor_resets[$1] = true if l =~ /Cursor\.reset\(\s*nil\s*,\s*:(\w+)/
      cursor_resets[$1] = true if l =~ /UIV21\.reset\(\s*:(\w+)/
      sc_tags[$1] ||= rel if l =~ /speak_changed\(\s*:(\w+)/
    end

    next if allow.include?(rel)
    next unless src =~ /PokeAccess\.speak|speak_clean|say_dialogue/
    guarded = src.scan(/(?:==|!=)\s*@((?:last|prev|seen)\w*)/).flatten |
              src.scan(/@((?:last|prev|seen)\w*)\s*(?:==|!=)/).flatten
    guarded.uniq.each do |iv|
      offenders.push("#{rel}: @#{iv}") unless reset_in_method.call(lines, iv)
    end
  end

  eq("dedup de modulo con guarda y sin reset en metodo", offenders.sort, [])

  missing = cursor_slots.reject { |slot, (_f, selfkey)| selfkey || cursor_resets[slot] }
  eq("slots globales de Cursor sin reset ni clave autoinvalidante",
     missing.map { |slot, pair| "#{pair[0]}: :#{slot}" }.sort, [])

  bare_tags = sc_tags.reject { |tag, _f| cursor_resets[tag] }
  eq("tags de speak_changed sin su UIV21.reset",
     bare_tags.map { |tag, f| "#{f}: :#{tag}" }.sort, [])
end
