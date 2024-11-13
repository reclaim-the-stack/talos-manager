require "open3"

class Talosctl
  def initialize(config_string)
    @config_string = config_string
  end

  def kubernetes_version
    success, stdout, _stderr = run("get apiserverconfig -o json")
    return unless success

    apiserverconfig = JSON.parse(stdout)
    apiserver_image = apiserverconfig.dig("spec", "image")

    unless apiserver_image
      Rails.logger.warning "WARNING: Unexpectedly failed to find image in apiserverconfig"
      return
    end

    version = apiserver_image.split(":").last.delete_prefix("v")
    unless version.match?(/^\d+\.\d+\.\d+$/)
      Rails.logger.warning "WARNING: Unexpectedly failed to get version from apiserverconfig image: '#{version}'"
      return
    end

    version
  end

  def run(command)
    command = "talosctl --talosconfig=#{config_file.path} #{command}"
    Rails.logger.info "Running command: #{command}"

    Open3.popen3(command) do |_stdin, stdout, stderr, wait_thread|
      [wait_thread.value.success?, stdout.read, stderr.read]
    end
  end

  def config_file
    return @config_file if defined?(@config_file)

    @config_file = Tempfile.new("talosconfig").tap do |file|
      file.write(@config_string)
      file.close
    end
  end
end
