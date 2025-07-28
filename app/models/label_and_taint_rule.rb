class LabelAndTaintRule < ApplicationRecord
  validates_presence_of :match
  validate :at_least_one_label_or_taint
  validate :validate_labels
  validate :validate_taints

  def labels_as_array
    labels.to_s.split(",")
  end

  def taints_as_array
    taints.to_s.split(",")
  end

  private

  def at_least_one_label_or_taint
    if labels.blank? && taints.blank?
      errors.add(:labels, "must have at least one label or taint")
      errors.add(:taints, "must have at least one label or taint")
    end
  end

  # This validation approximates the official standard for kubernetes labels, but not precisely:
  #
  # Labels are key/value pairs. Valid label keys have two segments: an optional prefix and name, separated by a
  # slash (/). The name segment is required and must be 63 characters or less, beginning and ending with an
  # alphanumeric character ([a-z0-9A-Z]) with dashes (-), underscores (_), dots (.), and alphanumerics between.
  # The prefix is optional. If specified, the prefix must be a DNS subdomain: a series of DNS labels separated by
  # dots (.), not longer than 253 characters in total, followed by a slash (/).
  #
  # If the prefix is omitted, the label Key is presumed to be private to the user. Automated system components
  # (e.g. kube-scheduler, kube-controller-manager, kube-apiserver, kubectl, or other third-party automation) which
  # add labels to end-user objects must specify a prefix.
  #
  # The kubernetes.io/ and k8s.io/ prefixes are reserved for Kubernetes core components.
  #
  # Valid label value:
  #   - must be 63 characters or less (can be empty),
  #   - unless empty, must begin and end with an alphanumeric character ([a-z0-9A-Z]),
  #   - could contain dashes (-), underscores (_), dots (.), and alphanumerics between.
  def validate_labels
    labels_as_array.each do |label|
      error = validate_label(label)
      errors.add(:labels, error) if error
    end
  end

  # Via https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#taint
  # A taint consists of a key, value, and effect. As an argument here, it is expressed as key=value:effect.
  # The key must begin with a letter or number, and may contain letters, numbers, hyphens, dots, and underscores,
  # up to 253 characters. Optionally, the key can begin with a DNS subdomain prefix and a single '/', like
  # example.com/my-app. The value is optional. If given, it must begin with a letter or number, and may contain
  # letters, numbers, hyphens, dots, and underscores, up to 63 characters. The effect must be NoSchedule,
  # PreferNoSchedule or NoExecute.
  def validate_taints
    taints_as_array.each do |taint|
      if taint.exclude?(":")
        errors.add(:taints, "must be in the format of key=value:Effect")
        return # rubocop:disable Lint/NonLocalExitFromIterator
      end

      label, effect = taint.split(":", 2)

      if %w[NoSchedule PreferNoSchedule NoExecute].exclude?(effect)
        errors.add(:taints, "effect must be one of: NoSchedule, PreferNoSchedule, NoExecute")
        return # rubocop:disable Lint/NonLocalExitFromIterator
      end

      error = validate_label(label)
      errors.add(:taints, error) if error
    end
  end

  def validate_label(label)
    if label.exclude?("=")
      return "must include an equals sign to separate key and value"
    end

    key, value = label.split("=", 2)

    if key.blank? || key.length > 316
      return "keys must be between 1 and 316 characters long"
    end

    unless key.match?(%r{\A(([A-Za-z0-9][-A-Za-z0-9_./]*)?[A-Za-z0-9])?\z})
      return "keys must consist of alphanumeric characters, '-', '_', '/' or '.', and must start and end with an alphanumeric character (this validation is stricter than Kubernetes itself but let's be reasonable)." # rubocop:disable Layout/LineLength
    end

    unless value.match?(/\A(([A-Za-z0-9][-A-Za-z0-9_.]*)?[A-Za-z0-9])?\z/)
      "values must consist of alphanumeric characters, '-', '_' or '.', and must start and end with an alphanumeric character."
    end
  end
end
