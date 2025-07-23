require "open3"

# Wrapper around the kubectl command line tool to interact with Kubernetes clusters

class Kubectl
  def initialize(config_string)
    @config_string = config_string
  end

  def run(command)
    command = "kubectl --kubeconfig=#{config_file.path} #{command}"
    Rails.logger.info "[Kubectl] Running command: #{command}"

    Open3.popen3(command) do |_stdin, stdout, stderr, wait_thread|
      [wait_thread.value.success?, stdout.read, stderr.read]
    end
  end

  private

  def config_file
    return @config_file if defined?(@config_file)

    @config_file = Tempfile.new("kubeconfig").tap do |file|
      file.write(@config_string)
      file.flush
    end
  end
end
