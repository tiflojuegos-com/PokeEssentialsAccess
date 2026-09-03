# Module-held dedup state outlives every screen: nothing disposes a module, so a "@last" that only ever
# fills up makes the SECOND visit silent -- the reader compares the fresh screen against a key kept from
# the previous one and concludes nothing changed. Readers shipped that way speak perfectly on every first
# visit, which is why no play session catches them; the reset path is the whole difference, so its absence
# is what this check hunts.
#
# Four rules, all heuristic, all aimed at the ABSENCE family only (a reset that restores a stale key, as
# a stack pop can, is beyond a static scan):
#   1. a file that speaks and guards on a module ivar named like dedup state (@last*/@prev*/@seen*) must
#      also assign nil to that ivar somewhere INSIDE a method. The module-body initializer does not count:
#      it runs once per process, which is exactly the lifetime being guarded against.
#   2. a Cursor call on the module-wide table (holder nil, literal slot) must have a matching
#      Cursor.reset(nil, slot) or UIV21.reset(slot) somewhere in the tree, unless the key on that same
#      line self-invalidates per screen (__id__ / object_id).
#   3. every literal speak_changed tag needs a UIV21.reset of that tag somewhere: those tags reach the
#      module-wide table through a VARIABLE slot, which rule 2 cannot see.
#   4. every INSTANCE-held Cursor slot must either have a reset somewhere or sit in SELF_SCOPED below.
#      The list is the claim, made explicit: this slot's holder is born and dies with the screen it
#      serves (or its key self-invalidates), so no reset is needed. A scene that HOSTS sub-screens
#      outlives them -- the family that muted the Pokedex search and the PC grid -- and a new slot on
#      such a scene must ship a reset, not a new line here.
# Files where a missing reset IS the design carry their justification in ALLOW.
Suite.define("static/dedup: el estado de modulo tiene camino de reset") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  files = Dir[File.join(root, "{core,games,plugins}", "**", "*.rb")].sort
  truthy("el barrido alcanza las tres raices",
         files.length > 150 && ["/core/", "/games/", "/plugins/"].all? { |d| files.any? { |f| f.tr("\\", "/").include?(d) } })

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
  scene_slots = {}
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
      elsif l =~ /Cursor\.(?:announce|changed\?|on_change)\(\s*[A-Za-z_@][A-Za-z0-9_.]*\s*,\s*:(\w+)/
        scene_slots[$1] ||= rel
      end
      cursor_resets[$1] = true if l =~ /Cursor\.reset\(\s*[^,]+,\s*:(\w+)/
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

  # Rule 4. Each entry asserts: the holder is born and dies with its screen, or the key self-invalidates.
  self_scoped = %w[
    afr_archer afr_tables album_state arcky_species auto_focus awk_ach awk_ball awk_comp awk_evs
    awk_glos awk_hist_section awk_lore awk_talisman bdx_page cc_dots charcreate dex_page
    gacha gacha_banner gender_sel hatch hof hof_pk if2_challenge if2_door if2_starter if_fusion
    list_entry ls_autosub mgift_card mono_type move_idx opt_tab pchm_ring place_idx place_row pm
    rea_baya rea_mankey rea_morse rea_postre_col rea_ppt rea_timon rea_timon_dir ready_last rem_build
    rem_tree ribbon_idx rse_starter sb_place slot_wager starter_sel sum_key sumkey support tl tm_name
    vp_msg wardrobe_row opt_val tp_cell pnav_hearts bb_key mbs_sel ck_target mm_help mm_sel mg_score
   book_page rea_hof_slide]
  scene_missing = scene_slots.reject { |slot, _f| cursor_resets[slot] || self_scoped.include?(slot) }
  eq("slots de instancia sin reset y sin declaracion en SELF_SCOPED",
     scene_missing.map { |slot, f| "#{f}: :#{slot}" }.sort, [])
end
