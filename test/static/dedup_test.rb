# Dedup state a module keeps outlives every screen, so it needs a reset path or the second visit is silent: a speaking
# file guarding on a module @last*/@prev*/@seen* ivar sets it nil inside some method; a slot of the module-wide Cursor
# table (holder nil) has a Cursor.reset or UIV21.reset unless the key on its line self-invalidates (__id__,
# object_id); every speak_changed tag has its UIV21.reset; and every instance-held slot has a reset or sits in
# SELF_SCOPED, its holder living and dying with its screen.
class DedupTest < PokeAccessTest
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  # Files whose missing reset is the design: dialogue.rb's @last_say pairs with @last_say_t, a clock, and the time
  # window is its reset.
  ALLOW = ["core/dialogue/dialogue.rb"].freeze
  # Instance-held slots whose holder is born and dies with its screen, or whose key self-invalidates.
  SELF_SCOPED = %w[
    afr_archer afr_tables afr_kick afr_race_count afr_race_lap afr_race_half afr_race_bend afr_race_place afr_race_hp
    afr_race_turbo album_state arcky_species auto_focus pach awk_ball awk_binfo awk_comp awk_evs
    awk_glos awk_hist_section awk_lore awk_talisman bdx_page cc_dots charcreate dex_page
    gacha gacha_banner hatch hof hof_pk hof_record load_info ready_side if2_challenge if2_door if2_starter if_fusion
    list_entry ls_autosub mgift_card mono_type move_idx opt_tab pchm_ring place_idx place_row pm
    rea_baya rea_mankey rea_postre_col rea_ppt rea_timon rea_timon_dir ready_last rem_build
    rem_tree ribbon_idx rse_starter sb_place slot_spin slot_wager starter_sel sum_key sumkey support tl tm_name
    vp_msg wardrobe_row opt_val tp_cell pnav_hearts bb_key mbs_sel ck_target mm_help mm_sel mg_score
    triad_score hof_welcome dex_header voltseon_entry modular_selection mine_wall pc_mode ss2_boxpick ss2_boxset
    ss2_boxpin su_block arcky_mode arcky_preview ss2_tutor showcase ev_alloc
    book_page hofbw6_slide party_help enc_cursor cc_timer pbk_cond ss2_adv_overlay ss2_adv_hearts ss2_adv_keys
    ss2_adv_floor hof_text ev_value adv_dex bdx_header zud_raid_row gacha_counts rem_limits
    zlair_here zlair_list_open zlair_party zlair_prize zlair_rental_state zlair_row zlair_speed zlair_tutor
    ura_bag_list ura_dex rj_achievement rj_luckswap rv_tw_frame deso_quest_page ss2_hof_view if_hof_page zball_hint
    if_hat if_hat_pos rem_pokocho ura_bmart_berries ura_ctrl ura_opt_help ura_dex_search
    ura_pod_info move_list_title relearn_pokemon charcreate_name rea_baile_demo rea_baile_turn rea_baile_grade rea_ppt_start
    rea_ppt_timeout rea_morse_keys rea_morse_guide rea_timon_keys rea_timon_chart rea_pesca_foe hofbw6_keys hofbw6_card
    rea_credits hofbw6_record if2_ct_applause sv_ct_applause sv_ct_order if2_quiz_streak if2_nav_zone if2_qm_popup if2_radar_weather
    chall_applause chall_order
    sb_mart_desc fl_roulette_coins rj_dex_head rj_map rv_tutor unown_cell pgwatch_info wall_clock_open sv_clock
    sv_credits sv_credits_end sv_drawer sv_pool new_dexnav screen_title
    wf_album_card wf_album_gen wf_bpshop wf_editor_open wf_history_open wf_island wf_pshop_sort wf_rent
    wf_rent_help wf_starter wf_stat wf_stats wf_swap_help wf_turn wf_turn_top ekans_sitrus
  ].freeze
  # The tree and its findings, read once per run: neither changes during one.
  SCANS = {}

  test "sweeps core, games and plugins" do
    assert_operator tree.length, :>, 150, "the files it reads"
    assert_equal %w[core games plugins], tree.map { |rel, _text| rel[%r{\A[^/]+}] }.uniq.sort
  end

  test "resets every module dedup ivar a speaking file guards on" do
    assert_equal [], tree_findings[:guards]
  end

  test "resets every slot of the module-wide Cursor table or keys it to invalidate itself" do
    assert_equal [], tree_findings[:globals]
  end

  test "resets every speak_changed tag" do
    assert_equal [], tree_findings[:tags]
  end

  test "resets every instance-held Cursor slot or declares it self-scoped" do
    assert_equal [], tree_findings[:instances]
  end

  test "every self-scoped slot is one the mod still keys a holder's state with" do
    assert_equal [], stale_self_scoped(tree, SELF_SCOPED)
  end

  test "reports a guarded module ivar that no method resets, though it is set nil at load" do
    src = "module PokeAccess\n  @last_text = nil\n  def self.say(t)\n    return if t == @last_text\n" \
          "    @last_text = t\n    PokeAccess.speak(t)\n  end\nend\n"
    assert_equal ["core/planted.rb: @last_text"], findings([["core/planted.rb", src]])[:guards]
  end

  test "takes a nil assignment inside any method, one-liners included, as the reset path" do
    say = "module PokeAccess\n  def self.say(t)\n    return if @prev_row != t || t == @seen_key\n" \
          "    PokeAccess.speak(t)\n  end\n"
    { "  def self.forget; @prev_row = nil; @seen_key = nil; end\nend\n" => [],
      "  def self.forget\n    @prev_row = nil\n  end\nend\n" => ["core/planted.rb: @seen_key"],
      "end\n@prev_row = nil\n@seen_key = nil\n" => ["core/planted.rb: @prev_row", "core/planted.rb: @seen_key"]
    }.each do |tail, want|
      assert_equal want, findings([["core/planted.rb", say + tail]])[:guards], "with #{tail.inspect}"
    end
  end

  test "checks only the files that speak, and spares the allowed ones" do
    guarded = "module PokeAccess\n  def self.say(t)\n    return if t == @last_text\n    @last_text = t\n"
    assert_equal [], findings([["core/planted.rb", guarded + "    show(t)\n  end\nend\n"]])[:guards], "a silent file"
    spoken = guarded + "    PokeAccess.speak(t)\n  end\nend\n"
    assert_equal [], findings([["core/dialogue/dialogue.rb", spoken]])[:guards], "an allowed file"
  end

  test "reports a module-wide Cursor slot with no reset, and spares one that is reset or keyed to invalidate itself" do
    call = "PokeAccess::Cursor.announce(nil, :planted_row, i) { say(i) }\n"
    { "" => ["core/planted.rb: :planted_row"],
      "PokeAccess::Cursor.reset(nil, :planted_row)\n" => [],
      "PokeAccess::UIV21.reset(:planted_row)\n" => [],
      "PokeAccess::Cursor.changed?(nil, :planted_row, scene.object_id)\n" => [] }.each do |more, want|
      assert_equal want, findings([["core/planted.rb", call + more]])[:globals], "with #{more.inspect}"
    end
  end

  test "reports a speak_changed tag with no UIV21.reset" do
    call = "PokeAccess.speak_changed(:planted_tag, t)\n"
    assert_equal ["core/planted.rb: :planted_tag"], findings([["core/planted.rb", call]])[:tags]
    reset = ["core/b.rb", "PokeAccess::UIV21.reset(:planted_tag)\n"]
    assert_equal [], findings([["core/planted.rb", call], reset])[:tags], "reset in another file"
  end

  test "reports an instance-held slot with neither a reset nor a self-scoped declaration" do
    call = "PokeAccess::Cursor.changed?(@scene, :planted_slot, i)\n"
    assert_equal ["core/planted.rb: :planted_slot"], findings([["core/planted.rb", call]])[:instances]
    reset = call + "PokeAccess::Cursor.reset(@scene, :planted_slot)\n"
    assert_equal [], findings([["core/planted.rb", reset]])[:instances], "reset"
    assert_equal [], findings([["core/planted.rb", call]], %w[planted_slot])[:instances], "declared self-scoped"
  end

  test "reports a self-scoped slot the mod names only as something else" do
    src = "PokeAccess::Cursor.changed?(scene, :planted_slot, i)\nsay_counter(@scene, :planted_helper, t)\n" \
          "PokeAccess::I18n.t(:planted_key)\n"
    assert_equal ["planted_key", "planted_gone"],
                 stale_self_scoped([["core/planted.rb", src]], %w[planted_slot planted_helper planted_key planted_gone])
  end

  private

  # The mod's files as [relative path, text], read once: the tree does not change during a run.
  def tree
    SCANS[:tree] ||= Dir[File.join(ROOT, "{core,games,plugins}", "**", "*.rb")].sort.map do |path|
      [path[(ROOT.length + 1)..-1].tr("\\", "/"), File.read(path)]
    end
  end

  # The findings over the mod's files, scanned once.
  def tree_findings
    SCANS[:findings] ||= findings(tree)
  end

  # True when iv is assigned nil inside a def (one-liners count), tracked by def/end indentation.
  def reset_in_method?(lines, iv)
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

  # The [path, text] sources' missing reset paths as { :guards, :globals, :tags, :instances => ["path: name"] }.
  def findings(sources, self_scoped = SELF_SCOPED)
    guards = []
    globals = {}
    instances = {}
    tags = {}
    resets = {}
    sources.each do |rel, src|
      lines = src.split("\n")
      lines.each do |l|
        if l =~ /Cursor\.(?:announce|changed\?|on_change)\(\s*nil\s*,\s*:(\w+)/
          slot = $1
          selfkey = (l =~ /__id__|object_id/) ? true : false
          prev = globals[slot]
          globals[slot] = [rel, (prev ? prev[1] : false) || selfkey]
        elsif l =~ /Cursor\.(?:announce|changed\?|on_change)\(\s*[A-Za-z_@][A-Za-z0-9_.]*\s*,\s*:(\w+)/
          instances[$1] ||= rel
        end
        resets[$1] = true if l =~ /Cursor\.reset\(\s*[^,]+,\s*:(\w+)/
        resets[$1] = true if l =~ /UIV21\.reset\(\s*:(\w+)/
        tags[$1] ||= rel if l =~ /speak_changed\(\s*:(\w+)/
      end
      next if ALLOW.include?(rel) || src !~ /PokeAccess\.speak|speak_clean|say_dialogue/
      guarded = src.scan(/(?:==|!=)\s*@((?:last|prev|seen)\w*)/).flatten |
                src.scan(/@((?:last|prev|seen)\w*)\s*(?:==|!=)/).flatten
      guarded.uniq.each { |iv| guards.push("#{rel}: @#{iv}") unless reset_in_method?(lines, iv) }
    end
    unreset = globals.reject { |slot, (_f, selfkey)| selfkey || resets[slot] }.map { |slot, (f, _k)| [slot, f] }
    { :guards => guards.sort,
      :globals => named(unreset),
      :tags => named(tags.reject { |tag, _f| resets[tag] }),
      :instances => named(instances.reject { |slot, _f| resets[slot] || self_scoped.include?(slot) }) }
  end

  # "path: :slot" for each [slot, path], sorted.
  def named(pairs)
    pairs.map { |slot, path| "#{path}: :#{slot}" }.sort
  end

  # The slots no call of the [path, text] sources keys a holder's state with (as its second argument, after the
  # holder), in the order given.
  def stale_self_scoped(sources, slots)
    keyed = {}
    sources.each { |_rel, src| src.scan(/\(\s*[A-Za-z_@][A-Za-z0-9_.]*\s*,\s*:(\w+)/) { |m| keyed[m[0]] = true } }
    slots.reject { |s| keyed[s] }
  end
end
