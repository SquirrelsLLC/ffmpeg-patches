
# Author: Pierce Brooks

require 'rubygems'
require 'fileutils'
require 'logger'
require 'open3'

LOGGER = Logger.new(STDOUT)

def original(path)
  prefix = "FFmpeg-devel-"
  if (path.start_with?(prefix+"1"))
    return "./libavformat/http.c"
  end
  if (path.start_with?(prefix+"2"))
    return "./libavformat/http.c"
  end
  if (path.start_with?(prefix+"3"))
    return "./libavformat/hls.c"
  end
  return nil
end

def execute(arguments, options)
  LOGGER.info(arguments.join(" "))
  Open3.popen3(*arguments) do |stdin, stdout, stderr, waiter|
    if not (options.length == 0)
      for i in 0..(options.length-1)
        option = options[i]
        #LOGGER.info("#{option}")
        stdin.puts(option+"\n")
      end
    end
    stdout.each_line{|line| LOGGER.info("#{line}")}
    stdin.close
  end
  return 0
end

def depend(pwd, target)
  commands = ["libavcodec-dev", "libavdevice-dev", "libavfilter-dev", "libavformat-dev", "libswresample-dev", "libswscale-dev", "libssl-dev"]
  for i in 0..(commands.length-1)
    command = ["sudo", "apt-get", "build-dep", commands[i], "-y"]
    if not (execute(command, []) == 0)
      LOGGER.error("Depend failure (\"sudo apt-get build-dep\")?")
      return -1
    end
  end
  for i in 0..(commands.length-1)
    if not (commands[i].include?("libav"))
      command = ["sudo", "apt-get", "install", commands[i], "-y"]
      if not (execute(command, []) == 0)
        LOGGER.error("Depend failure (\"sudo apt-get install\")?")
        return -1
      end
    end
  end
  return 0
end

def clone(pwd, target)
  command = ["git", "clone", "https://git.ffmpeg.org/ffmpeg.git", File.join(pwd, target)]
  if not (execute(command, []) == 0)
    LOGGER.error("Clone failure?")
    return -1
  end
  return 0
end

def fetch(pwd, target)
  Dir.chdir(File.join(pwd, target))
  command = ["git", "fetch"]
  if not (execute(command, []) == 0)
    LOGGER.error("Fetch failure?")
    Dir.chdir(pwd)
    return -1
  end
  Dir.chdir(pwd)
  return 0
end

def clean(pwd, target)
  Dir.chdir(File.join(pwd, target))
  command = ["git", "clean", "-df"]
  if not (execute(command, []) == 0)
    LOGGER.error("Clean failure?")
    Dir.chdir(pwd)
    return -1
  end
  Dir.chdir(pwd)
  return 0
end

def reset(pwd, target)
  Dir.chdir(File.join(pwd, target))
  command = ["git", "reset", "--hard"]
  if not (execute(command, []) == 0)
    LOGGER.error("Reset failure?")
    Dir.chdir(pwd)
    return -1
  end
  Dir.chdir(pwd)
  return 0
end

def checkout(pwd, target, version)
  Dir.chdir(File.join(pwd, target))
  command = ["git", "checkout", version]
  if not (execute(command, []) == 0)
    LOGGER.error("Checkout failure?")
    Dir.chdir(pwd)
    return -1
  end
  Dir.chdir(pwd)
  return 0
end

def patch(pwd, target, version)
  patches = Dir.entries(File.join(pwd, version)).select{|entry| !File.directory?(entry)}
  for i in 0..(patches.length-1)
    path = patches[i]
    LOGGER.info("Patch: \"#{path}\"")
    if (path.end_with?(".patch"))
      Dir.chdir(File.join(pwd, target))
      update = original(path)
      if not (update == nil)
        command = ["patch", "--strip=1", "--batch", "-i", File.join(pwd, version, path)]
        if not (execute(command, []) == 0)
          LOGGER.error("Patch failure?")
          Dir.chdir(pwd)
          return -1
        end
      end
      Dir.chdir(pwd)
    end
  end
  return 0
end

def configure(pwd, target)
  Dir.chdir(File.join(pwd, target))
  command = ["./configure", "--enable-shared", "--disable-static", "--enable-openssl", "--prefix=/usr/local/"]
  if not (execute(command, []) == 0)
    LOGGER.error("Configure failure?")
    Dir.chdir(pwd)
    return -1
  end
  Dir.chdir(pwd)
  return 0
end

def make(pwd, target, parallels)
  Dir.chdir(File.join(pwd, target))
  command = ["make", "-j"+parallels]
  if not (execute(command, []) == 0)
    LOGGER.error("Make failure?")
    Dir.chdir(pwd)
    return -1
  end
  Dir.chdir(pwd)
  return 0
end

def install(pwd, target)
  Dir.chdir(File.join(pwd, target))
  command = ["sudo", "make", "install"]
  if not (execute(command, []) == 0)
    LOGGER.error("Install failure?")
    Dir.chdir(pwd)
    return -1
  end
  Dir.chdir(pwd)
  return 0
end

def update(pwd, target)
  command = ["sudo", "ldconfig"]
  if not (execute(command, []) == 0)
    LOGGER.error("Update failure?")
    Dir.chdir(pwd)
    return -1
  end
  return 0
end

def run(version, parallels)
  pwd = Dir.pwd
  target = "ffmpeg"
  if not (Dir.exists?(File.join(pwd, version)))
    LOGGER.error("Version problem (#{version})?")
    return -1
  end
  if (Dir.exists?(target))
=begin
    LOGGER.info("Removing #{target}...")
    FileUtils.rm_rf(target)
    LOGGER.info("Removed #{target}!")
=end
    if not (fetch(pwd, target) == 0)
      return -1
    end
  else
    if not (clone(pwd, target) == 0)
      return -1
    end
  end
  if not (clean(pwd, target) == 0)
    return -1
  end
  if not (reset(pwd, target) == 0)
    return -1
  end
  if not (checkout(pwd, target, version) == 0)
    return -1
  end
  if not (patch(pwd, target, version) == 0)
    return -1
  end
  if not (depend(pwd, target) == 0)
    return -1
  end
  if not (configure(pwd, target) == 0)
    return -1
  end
  if not (make(pwd, target, parallels) == 0)
    return -1
  end
  if not (install(pwd, target) == 0)
    return -1
  end
  if not (update(pwd, target) == 0)
    return -1
  end
  return 0
end

def launch(arguments)
  LOGGER.info("Running...")

  result = nil
  success = nil
  
  version = "n3.4"
  parallels = "4"

  if (arguments.length > 0)
    if (arguments.length > 1)
      result = run(arguments[0], arguments[1])
    else
      result = run(arguments[0], parallels)
    end
  else
    result = run(version, parallels)
  end

  if not (result == nil)
    if (result == 0)
      LOGGER.info("Successful!")
      success = true
    else
      LOGGER.error("Error?")
      success = false
    end
  else
    LOGGER.error("Error?")
    success = false
  end
  
  if not (success == nil)
    return success
  end
  return false
end

launch(ARGV)
