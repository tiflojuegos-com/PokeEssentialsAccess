module PokeAccess
  # Tip Cards (a fangame tutorial-card addon): pbDrawTip draws the focused card as bitmap
  # text, so a screen reader gets nothing. These read the focused card when shown or changed; the
  # title/body are localization tokens resolved through the game's own _INTL and cleaned of markup.

  # The spoken title + body of the focused tip card, or nil.
  def self.tip_card_text(scene)
    tips = PokeAccess.ivar(scene, :@tips)
    idx = PokeAccess.ivar(scene, :@index)
    tip = (tips && idx) ? tips[idx] : nil
    return nil unless tip
    info = (::Settings::TIP_CARDS_CONFIGURATION[tip] rescue nil)
    return nil unless info
    parts = []
    [:Title, :Text].each do |k|
      v = (info[k] rescue nil)
      next if v.nil? || v.to_s.empty?
      s = (_INTL(v) rescue v).to_s
      parts.push(clean(s)) unless s.empty?
    end
    parts.empty? ? nil : parts.join(". ")
  rescue StandardError
    nil
  end

  # The spoken title of the focused tip-card GROUP (the grouped browser), or nil.
  def self.tip_group_title(scene)
    groups = PokeAccess.ivar(scene, :@groups)
    sec = PokeAccess.ivar(scene, :@section)
    return nil unless groups.is_a?(Array) && sec && groups[sec]
    g = (::Settings::TIP_CARDS_GROUPS[groups[sec]] rescue nil)
    t = (g && g[:Title]) ? (_INTL(g[:Title]) rescue g[:Title]).to_s : nil
    (t && !t.empty?) ? clean(t) : nil
  rescue StandardError
    nil
  end
end

# Individual tip-card screen: read the card on open and each page change. No-op where the addon is absent.
PokeAccess::Hooks.after_hook("TipCard_Scene", :pbDrawTip) do |scene, _r, _a|
  t = PokeAccess.tip_card_text(scene)
  PokeAccess.speak(t, true) if t && !t.to_s.empty?
end

# Grouped tip-card browser (TipCardGroups_Scene): a group change calls pbDrawGroup (which calls pbDrawTip),
# and a page change calls pbDrawTip directly, so hooking pbDrawTip catches both. Prepend the group title
# when the group changed. (The group-list popup uses a command window, already read by the generic hook.)
PokeAccess::Hooks.after_hook("TipCardGroups_Scene", :pbDrawTip) do |scene, _r, _a|
  sec = PokeAccess.ivar(scene, :@section)
  parts = []
  if sec != scene.instance_variable_get(:@access_tcg_section)
    scene.instance_variable_set(:@access_tcg_section, sec)
    g = PokeAccess.tip_group_title(scene)
    parts.push(g) if g
  end
  c = PokeAccess.tip_card_text(scene)
  parts.push(c) if c && !c.to_s.empty?
  PokeAccess.speak(parts.join(". "), true) unless parts.empty?
end

# Tip-card group MENU (TipMenu_Scene): the screen you pick a group from. pbRedrawList redraws the focused
# group title as bitmap on each cursor move; read it, deduped by index. @elementos are the group keys.
PokeAccess::Hooks.after_hook("TipMenu_Scene", :pbRedrawList) do |scene, _r, _a|
  idx = PokeAccess.ivar(scene, :@index)
  if idx && idx != PokeAccess.ivar(scene, :@access_tipmenu_idx)
    scene.instance_variable_set(:@access_tipmenu_idx, idx)
    els = PokeAccess.ivar(scene, :@elementos)
    el = (els.is_a?(Array) ? els[idx] : nil)
    g = (el ? (::Settings::TIP_CARDS_GROUPS[el] rescue nil) : nil)
    t = (g && g[:Title]) ? (_INTL(g[:Title]) rescue g[:Title]).to_s : nil
    PokeAccess.speak_clean(t, true) if t && !t.to_s.empty?
  end
end
