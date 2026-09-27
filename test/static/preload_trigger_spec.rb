# loader/preload_access.rb in a child Ruby over a synthetic game folder: the toolkit loads once, on the first frame
# with $scene set or after Main's pbCallTitle exists, never while the game's scripts are still being evaluated.
Suite.define("static: the preload waits for the game's scripts to finish before loading the toolkit") do
  require "fileutils"
  root = File.expand_path("../..", File.dirname(__FILE__))
  preload = File.join(root, "loader", "preload_access.rb")
  truthy "the preload script is where the launcher copies it from", File.file?(preload)

  base = File.join(File.dirname(__FILE__), "tmp_preload")
  FileUtils.rm_rf(base)
  FileUtils.mkdir_p(File.join(base, "accessibility", "data"))
  begin
    File.open(File.join(base, "accessibility", "boot.rb"), "w") do |f|
      f.write("File.open('booted.txt', 'a') { |g| g.write(\"boot\\n\") }\n")
    end

    driver =File.join(base, "driver.rb")
    File.open(driver, "w") do |f|
      f.write(<<-'RB')
module Graphics
  def self.update(*a); nil; end
end
load ARGV[0]
booted = lambda { File.exist?("booted.txt") ? "si" : "no" }
400.times { Graphics.update }
print "durante_la_pausa=", booted.call, " "
# Main runs: its pbCallTitle appears, and only then is the game whole. Declared the way a game declares it
# -- a plain top-level def, which Ruby files away as a PRIVATE method of Object -- because define_method
# makes a PUBLIC one, and that is the branch no real game exercises: with a public method the check passes
# through method_defined? and private_method_defined? could be deleted with this spec still green, leaving
# the fallback dead in all fifteen games.
eval("def pbCallTitle; nil; end", TOPLEVEL_BINDING)
print "es_privado=", (Object.private_method_defined?(:pbCallTitle) && !Object.method_defined?(:pbCallTitle)) ? "si" : "no", " "
Graphics.update
print "tras_terminar_los_scripts=", booted.call, " "
print "veces=", (File.exist?("booted.txt") ? File.read("booted.txt").split("\n").length : 0)
      RB
    end
    out = IO.popen([RbConfig.ruby, driver, preload], :chdir => base, :err => [:child, :out]) { |io| io.read }
    truthy "the mod does NOT load while the game is still evaluating its scripts", out.include?("durante_la_pausa=no")
    truthy "and loads as soon as the script list has finished", out.include?("tras_terminar_los_scripts=si")
    truthy "driven through the shape a game really declares: a top-level def, private on Object",
           out.include?("es_privado=si")
    truthy "exactly once", out.include?("veces=1")

    driver2 =File.join(base, "driver2.rb")
    File.open(driver2, "w") do |f|
      f.write(<<-'RB')
module Graphics
  def self.update(*a); nil; end
end
load ARGV[0]
$scene = Object.new
Graphics.update
print "con_scene_al_primer_frame=", (File.exist?("booted2.txt") ? "si" : "no")
      RB
    end
    File.open(File.join(base, "accessibility", "boot.rb"), "w") do |f|
      f.write("File.open('booted2.txt', 'a') { |g| g.write(\"boot\\n\") }\n")
    end
    out2 = IO.popen([RbConfig.ruby, driver2, preload], :chdir => base, :err => [:child, :out]) { |io| io.read }
    truthy "with the main loop running the toolkit loads on the very first frame",
           out2.include?("con_scene_al_primer_frame=si")

    driver3 = File.join(base, "driver3.rb")
    File.open(driver3, "w") do |f|
      f.write(<<-'RB')
module Graphics
  def self.update(*a); nil; end
end
# Rejuvenation evaluates its scripts on a thread and sets $scene before the thread ends.
class ThreadLoader
  @@scriptLoadThread = Thread.new { sleep 0.3 }
  def self.awaitScripts; @@scriptLoadThread.join; @@scriptLoadThread = nil; end
end
load ARGV[0]
$scene = Object.new
Graphics.update
print "con_el_hilo_vivo=", (File.exist?("booted3.txt") ? "si" : "no"), " "
ThreadLoader.awaitScripts
Graphics.update
print "tras_el_hilo=", (File.exist?("booted3.txt") ? "si" : "no")
      RB
    end
    File.open(File.join(base, "accessibility", "boot.rb"), "w") do |f|
      f.write("File.open('booted3.txt', 'a') { |g| g.write(\"boot\\n\") }\n")
    end
    out3 = IO.popen([RbConfig.ruby, driver3, preload], :chdir => base, :err => [:child, :out]) { |io| io.read }
    truthy "a game still loading its scripts on a thread waits for it, $scene set or not",
           out3.include?("con_el_hilo_vivo=no")
    truthy "and loads once the thread is done", out3.include?("tras_el_hilo=si")
  ensure
    FileUtils.rm_rf(base)
  end
end
