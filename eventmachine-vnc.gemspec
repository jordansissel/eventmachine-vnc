Gem::Specification.new do |spec|
  files = []
  dirs = %w{lib samples test bin}
  dirs.each do |dir|
    files += Dir["#{dir}/**/*"]
  end

  #svnrev = %x{svn info}.split("\n").grep(/Revision:/).first.split(" ").last.to_i
  rev = Time.now.strftime("%Y%m%d%H%M%S")
  spec.name = "eventmachine-vnc"
  spec.version = "0.1.#{rev}"
  spec.summary = "eventmachine vnc - vnc/rfb protocol support"
  spec.description = "VNC for EventMachine"
  spec.add_dependency("eventmachine")
  spec.files = files
  spec.require_paths << "lib"

  spec.author = "Jordan Sissel"
  spec.email = "jls@semicomplete.com"
  spec.homepage = "https://github.com/jordansissel/eventmachine-vnc"
end

