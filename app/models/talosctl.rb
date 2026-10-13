require "open3"

# Wrapper around the talosctl command line tool to interact with already bootstrapped Talos clusters

class Talosctl
  ConnectionRefusedError = Class.new(StandardError)

  def initialize(config_string)
    @config_string = config_string
  end

  def kubernetes_version
    # NOTE: Talos 1.14 added a final-kube-apiserver APIServerConfig resource alongside kube-apiserver,
    # so we fetch kube-apiserver by ID to get a single resource.
    success, stdout, _stderr = run("get apiserverconfig kube-apiserver -o jsonpath={.spec.image}")
    return unless success

    apiserver_image = stdout.strip

    if apiserver_image.blank?
      Rails.logger.warn "WARNING: Unexpectedly failed to find image in apiserverconfig"
      return
    end

    version = apiserver_image.split(":").last.delete_prefix("v")
    unless version.match?(/^\d+\.\d+\.\d+$/)
      Rails.logger.warn "WARNING: Unexpectedly failed to get version from apiserverconfig image: '#{version}'"
      return
    end

    version
  end

  def kubeconfig
    success, stdout, stderr = run("kubeconfig --merge=false -")
    raise "Failed to get kubeconfig: #{stderr}" unless success

    stdout
  end

  def run(command)
    command = "talosctl --talosconfig=#{config_file.path} #{command}"
    Rails.logger.info "[Talosctl] Running command: #{command}"

    success, stdout, stderr =
      Open3.popen3(command) do |_stdin, stdout, stderr, wait_thread|
        [wait_thread.value.success?, stdout.read, stderr.read]
      end

    raise ConnectionRefusedError, stderr if !success && stderr.include?("connection refused")

    [success, stdout, stderr]
  end

  private

  def config_file
    return @config_file if defined?(@config_file)

    @config_file = Tempfile.new("talosconfig").tap do |file|
      file.write(@config_string)
      file.close
    end
  end
end
