# Keep runner locals out of the game's TOPLEVEL_BINDING DSL evaluations.
module XenoverseCaseRunner
  def self.run(arguments)
    root = File.expand_path("../..", File.dirname(__FILE__))
    ENV['ESSENTIAL_PEA_SOURCE'] = root
    name = arguments.shift
    raise 'Invalid owned case' unless name && name =~ /\Axenoverse_[a-z_]+_test\.rb\z/
    path = File.join(root, 'test/support/xenoverse_cases', name)
    raise 'Missing owned case' unless File.file?(path)
    load path
    Minitest.run(arguments)
  end
end
exit(XenoverseCaseRunner.run(ARGV) ? 0 : 1)
