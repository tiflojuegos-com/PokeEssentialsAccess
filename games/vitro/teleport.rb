# Vitro's teleport menu (Teleport_Scene, 0332_Sandbox Mode, another version of PokeLiberty's): one destination at a time under
# @index, its name and description repainted by pbRefresh, or "???" while locked; said as the cursor moves, with its place in
# the list.
module PokeAccess
  module VitroTeleport
    # The destination as the screen paints it, then its place in the list while positions are said.
    def self.text(scene, index)
      list = PokeAccess.ivar(scene, :@destinations)
      dest = list[index]
      lines = [PokeAccess::DexEntry.unknown_marks("???")]
      if scene.pbUnlocked?(index)
        desc = dest[:desc].is_a?(Array) ? dest[:desc] : dest[:desc].to_s.split("\n")
        lines = [dest[:name].to_s] + desc.map { |line| PokeAccess.clean(line.to_s) }
      end
      PokeAccess.sentences(lines + [PokeAccess::Verbosity.position(index + 1, list.length)])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  focus_reader("Teleport_Scene", :on => :pbRefresh, :slot => :vitro_teleport, :close => :pbTransportar, :optional => true) do |index, scene|
    PokeAccess::VitroTeleport.text(scene, index)
  end
end
