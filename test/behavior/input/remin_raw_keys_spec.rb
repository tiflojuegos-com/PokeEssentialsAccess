# Reminiscencia reads F (text log), A (blessing odds, dating-sim tabs), V (message skip) and 1 to 4 (summary moves,
# party lead) raw, beside the pause menu's T and S: its profile registers each as an extra named by its uses, so the
# remap menu refuses them to other actions. Only the profile's extras block is evaluated, the list put back after.
module ReminRawKeys
  PATH = File.join(Harness::ROOT, "games", "reminiscencia", "menus.rb")

  # Runs the block with the extras menus.rb registers, then restores the registry.
  def self.with_extras
    saved = PokeAccess::Remap.extras.dup
    block = File.read(PATH)[/^PokeAccess::Game\.define\("reminiscencia"\) do\r?\n  remap_extra.*?^end\r?\n/m]
    PokeAccess::Remap.extras.clear
    eval(block, TOPLEVEL_BINDING, PATH)
    yield
  ensure
    PokeAccess::Remap.extras.replace(saved)
  end
end

Suite.define("reminiscencia: every raw key the game reads is an extra the remap menu will not give away") do
  rb = PokeAccess::Config.rebinds
  begin
    ReminRawKeys.with_extras do
      rows = PokeAccess::Remap.extras
      vks = rows.map { |row| row[1] }
      [0x54, 0x53, 0x46, 0x41, 0x56, 0x31, 0x32, 0x33, 0x34].each do |vk|
        truthy "0x#{vk.to_s(16)} is registered", vks.include?(vk)
      end
      truthy "T and S keep the names a saved binding uses",
             rows.assoc(:fast_travel) && rows.assoc(:fast_travel)[1] == 0x54 && rows.assoc(:help)[1] == 0x53
      en = PokeAccess::I18n.table("en")
      rows.each { |row| truthy "#{row[2]} is written in the languages", en.has_key?(row[2].to_s) }
      PokeAccess::Config.rebinds = {}
      eq "running on F is refused: F opens the text log", PokeAccess::Remap.conflict(0x46, :a), :text_log
      eq "left on A is refused: A turns the tabs", PokeAccess::Remap.conflict(0x41, :left), :game_a
      eq "fast travel on 1 is refused: 1 is a move on the summary", PokeAccess::Remap.conflict(0x31, :fast_travel), :key_1
      eq "help on 2 likewise", PokeAccess::Remap.conflict(0x32, :help), :key_2
      eq "confirm on V is refused: V skips messages", PokeAccess::Remap.conflict(0x56, :c), :skip_text
      PokeAccess::Config.language = :es
      label = PokeAccess::Remap.label(:fast_travel)
      truthy "T is named by all its uses", label.include?("Caja") && label.include?("habilidad") && label.include?("Bolsa")
      truthy "and S by its tabs and the skipped scene", PokeAccess::Remap.label(:help).include?("pestañas")
    end
  ensure
    PokeAccess::Config.rebinds = rb
  end
end
