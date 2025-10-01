# Intended to be run after a server is configured. It is expected that the reboot after configuration
# is applied can take a while which is why we keep retrying for some time (and eventually give up).

class LabelAndTaintJob < ApplicationJob
  def perform(server_id)
    server = Server.find(server_id)

    # We may be waiting for the first control plane server to be ready
    kubectl =
      30.times do |attempt|
        break server.kubectl
      rescue Cluster::NoControlPlaneError, Talosctl::ConnectionRefusedError
        Rails.logger.warn "Attempt #{attempt + 1}/30: No control plane found for server #{server.name}. Retrying in 10 seconds..." # rubocop:disable Layout/LineLength

        sleep 10 unless Rails.env.test?
      end

    unless kubectl.is_a?(Kubectl)
      Rails.logger.error "Failed to get kubectl for server #{server.name} after 30 attempts, aborting"
      return
    end

    # Wait 5 minutes for the server to be present in the cluster
    server_present =
      60.times.find do |attempt|
        success, _stdout, stderr = kubectl.run("get node #{server.name}")

        break true if success

        Rails.logger.warn "Attempt #{attempt + 1}/60: Waiting for #{server.name}. Output: #{stderr}. Retrying in 5 seconds..."
        sleep 5 unless Rails.env.test?
        false
      end

    unless server_present
      Rails.logger.error "Failed to confirm #{server.name} in the cluster after 60 attempts, aborting"
      return
    end

    matching_rules = LabelAndTaintRule.all.entries.select do |rule|
      server.name.include?(rule.match)
    end

    if matching_rules.empty?
      Rails.logger.info "No matching label and taint rules found for server #{server.name}"
    end

    labels = matching_rules.flat_map(&:labels_as_array).compact.uniq
    if labels.any?
      success, _, stderr = kubectl.run("label node #{server.name} --overwrite #{labels.join(' ')}")

      unless success
        Rails.logger.error "Failed to apply labels to server #{server.name}: #{stderr}"
      end
    end

    taints = matching_rules.flat_map(&:taints_as_array).compact.uniq
    if taints.any?
      success, _, stderr = kubectl.run("taint node #{server.name} #{taints.join(' ')}")
      unless success
        Rails.logger.error "Failed to apply taints to server #{server.name}: #{stderr}"
      end
    end

    # Whether we actually applied any labels or taints we set label_and_taint_job_completed_at
    # to indicate that we have at least confirmed the server to be present in the cluster.
    server.update!(label_and_taint_job_completed_at: Time.now)
  end
end
