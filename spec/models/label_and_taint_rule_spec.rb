RSpec.describe LabelAndTaintRule do
  it "must have at least one label or taint" do
    message = "must have at least one label or taint"

    latr = LabelAndTaintRule.new
    latr.validate

    expect(latr.errors[:labels]).to include message

    latr.taints = "key=value:NoSchedule"
    latr.validate

    expect(latr.errors[:labels]).not_to include message

    latr.taints = nil
    latr.labels = "key=value"
    latr.validate

    expect(latr.errors[:taints]).not_to include message
  end

  it "validates labels to avoid issues with Kubernetes" do
    latr = LabelAndTaintRule.new

    # Valid label
    latr.labels = "app=my-app"
    latr.validate
    expect(latr.errors[:labels]).to be_empty

    # Invalid label: missing equals sign
    latr.labels = "appmy-app"
    latr.validate
    expect(latr.errors[:labels]).to include "must include an equals sign to separate key and value"

    # Invalid label: key too long
    latr.labels = "a" * 317 + "=value"
    latr.validate
    expect(latr.errors[:labels]).to include "keys must be between 1 and 316 characters long"

    # Invalid label: key does not start and end with alphanumeric
    latr.labels = "app-@my-app=value"
    latr.validate
    expect(latr.errors[:labels]).to include "keys must consist of alphanumeric characters, '-', '_', '/' or '.', and must start and end with an alphanumeric character (this validation is stricter than Kubernetes itself but let's be reasonable)." # rubocop:disable Layout/LineLength

    # Invalid label: value does not start and end with alphanumeric
    latr.labels = "app=my-app-@"
    latr.validate
    expect(latr.errors[:labels]).to include "values must consist of alphanumeric characters, '-', '_' or '.', and must start and end with an alphanumeric character." # rubocop:disable Layout/LineLength
  end

  it "validates taints to avoid issues with Kubernetes" do
    latr = LabelAndTaintRule.new

    # Valid taint
    latr.taints = "key=value:NoSchedule"
    latr.validate
    expect(latr.errors[:taints]).to be_empty

    # Invalid taint: missing effect
    latr.taints = "key=value"
    latr.validate
    expect(latr.errors[:taints]).to include "must be in the format of key=value:Effect"

    # Invalid taint: invalid effect
    latr.taints = "key=value:InvalidEffect"
    latr.validate
    expect(latr.errors[:taints]).to include "effect must be one of: NoSchedule, PreferNoSchedule, NoExecute"

    # Invalid taint: missing equals sign
    latr.taints = "keyvalue:NoSchedule"
    latr.validate
    expect(latr.errors[:taints]).to include "must include an equals sign to separate key and value"

    # Invalid taint: key does not start with alphanumeric
    latr.taints = "-key=value:NoSchedule"
    latr.validate
    expect(latr.errors[:taints]).to include "keys must consist of alphanumeric characters, '-', '_', '/' or '.', and must start and end with an alphanumeric character (this validation is stricter than Kubernetes itself but let's be reasonable)." # rubocop:disable Layout/LineLength

    # Invalid taint: key too long
    latr.taints = "a" * 317 + "=value:NoSchedule"
    latr.validate
    expect(latr.errors[:taints]).to include "keys must be between 1 and 316 characters long"

    # Invalid taint: value does not start and end with alphanumeric
    latr.taints = "key=value-@:NoSchedule"
    latr.validate
    expect(latr.errors[:taints]).to include "values must consist of alphanumeric characters, '-', '_' or '.', and must start and end with an alphanumeric character." # rubocop:disable Layout/LineLength
  end

  describe "#labels_as_array" do
    it "returns an array of labels" do
      latr = LabelAndTaintRule.new(labels: "app=my-app,env=production")
      expect(latr.labels_as_array).to eq(["app=my-app", "env=production"])
    end

    it "returns an empty array if labels are nil" do
      latr = LabelAndTaintRule.new(labels: nil)
      expect(latr.labels_as_array).to eq([])
    end

    it "returns an empty array if labels are empty" do
      latr = LabelAndTaintRule.new(labels: "")
      expect(latr.labels_as_array).to eq([])
    end
  end

  describe "#taints_as_array" do
    it "returns an array of taints" do
      latr = LabelAndTaintRule.new(taints: "key=value:NoSchedule,key2=value2:PreferNoSchedule")
      expect(latr.taints_as_array).to eq(["key=value:NoSchedule", "key2=value2:PreferNoSchedule"])
    end

    it "returns an empty array if taints are nil" do
      latr = LabelAndTaintRule.new(taints: nil)
      expect(latr.taints_as_array).to eq([])
    end

    it "returns an empty array if taints are empty" do
      latr = LabelAndTaintRule.new(taints: "")
      expect(latr.taints_as_array).to eq([])
    end
  end
end
