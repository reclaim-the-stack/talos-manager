class LabelAndTaintRulesController < ApplicationController
  def index
    @label_and_taint_rules = LabelAndTaintRule.order(:id).all
  end

  def new
    @label_and_taint_rule = LabelAndTaintRule.new
  end

  def create
    label_and_taint_rule_params = params.expect(label_and_taint_rule: %i[match labels taints])

    @label_and_taint_rule = LabelAndTaintRule.new(label_and_taint_rule_params)

    if @label_and_taint_rule.save
      redirect_to label_and_taint_rules_path, notice: "Label and Taint Rule created successfully."
    else
      render :new, status: 422
    end
  end

  def edit
    @label_and_taint_rule = LabelAndTaintRule.find(params[:id])
  end

  def update
    @label_and_taint_rule = LabelAndTaintRule.find(params[:id])

    label_and_taint_rule_params = params.expect(label_and_taint_rule: %i[match labels taints])

    if @label_and_taint_rule.update(label_and_taint_rule_params)
      redirect_to label_and_taint_rules_path, notice: "Label and Taint Rule updated successfully."
    else
      render :edit, status: 422
    end
  end

  def destroy
    label_and_taint_rule = LabelAndTaintRule.find(params[:id])
    label_and_taint_rule.destroy

    redirect_to label_and_taint_rules_path, notice: "Label and Taint Rule deleted successfully."
  end
end
