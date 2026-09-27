# Module-held dedup state outlives every screen, so it needs a reset path or the second visit is silent. Heuristics:
#   1. a speaking file guarding on a module @last*/@prev*/@seen* ivar assigns it nil inside some method;
#   2. a Cursor call on the module-wide table (holder nil, literal slot) has a Cursor.reset(nil, slot) or
#      UIV21.reset(slot) somewhere, unless the key on its line self-invalidates (__id__ / object_id);
#   3. every literal speak_changed tag has a UIV21.reset of that tag;
#   4. every instance-held Cursor slot has a reset or sits in self_scoped (its holder lives and dies with its screen).
# Files where a missing reset is the design go in allow, with their reason.
Suite.define("static/dedup: el estado de modulo tiene camino de reset") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  files = Dir[File.join(root, "{core,games,plugins}", "**", "*.rb")].sort
  truthy("el barrido alcanza las tres raices",
         files.length > 150 && ["/core/", "/games/", "/plugins/"].all? { |d| files.any? { |f| f.tr("\\", "/").include?(d) } })

  # dialogue.rb: @last_say pairs with @last_say_t, a clock -- the time window is the reset.
  allow = ["core/dialogue/dialogue.rb"]

  # True when iv is assigned nil inside a def (one-liners count), tracked by def/end indentation.
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
    afr_archer afr_tables afr_kick afr_race_count afr_race_lap afr_race_half afr_race_bend afr_race_place afr_race_hp
    afr_race_turbo album_state arcky_species auto_focus pach awk_ball awk_binfo awk_comp awk_evs
    awk_glos awk_hist_section awk_lore awk_talisman bdx_page cc_dots charcreate dex_page
    gacha gacha_banner gender_sel hatch hof hof_pk if2_challenge if2_door if2_starter if_fusion
    list_entry ls_autosub mgift_card mono_type move_idx opt_tab pchm_ring place_idx place_row pm
    rea_baya rea_mankey rea_morse rea_postre_col rea_ppt rea_timon rea_timon_dir ready_last rem_build
    rem_tree ribbon_idx rse_starter sb_place slot_wager starter_sel sum_key sumkey support tl tm_name
    vp_msg wardrobe_row opt_val tp_cell pnav_hearts bb_key mbs_sel ck_target mm_help mm_sel mg_score
   triad_score hof_welcome dex_header voltseon_entry mine_wall pc_mode ss2_boxpick ss2_boxset ss2_boxpin su_block arcky_mode arcky_preview ss2_tutor showcase ev_alloc
   book_page hofbw6_slide party_help enc_cursor cc_timer pbk_cond ss2_adv_overlay ss2_adv_hearts ss2_adv_keys
   ss2_adv_floor hof_text ev_value adv_dex bdx_header zud_raid_row gacha_counts rem_limits reb_tutor
   ura_bag_list ura_dex rj_achievement rj_blessing rj_luckswap rv_tw_frame deso_quest_page ss2_hof_view zball_hint
   if_hat if_hat_pos ins_leaf rem_pokocho ura_bmart_berries ura_ctrl ura_opt_help ura_dex_search
   ura_pod_info move_list_title charcreate_name rea_baile_demo rea_baile_turn rea_baile_grade rea_ppt_start
   rea_ppt_timeout rea_morse_keys rea_morse_guide rea_timon_keys rea_timon_chart rea_pesca_foe hofbw6_keys hofbw6_card
   rea_credits hofbw6_record if2_ct_applause if2_quiz_streak if2_nav_zone if2_qm_popup if2_radar_weather
   sb_mart_desc fl_roulette_coins rj_dex_head rj_map rv_tutor]
  scene_missing = scene_slots.reject { |slot, _f| cursor_resets[slot] || self_scoped.include?(slot) }
  eq("slots de instancia sin reset y sin declaracion en SELF_SCOPED",
     scene_missing.map { |slot, f| "#{f}: :#{slot}" }.sort, [])
end
