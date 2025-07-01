class ApiKeysController < ApplicationController
  def new
    provider = params[:provider] || "hetzner_robot"
    @api_key = ApiKey.new(provider:)
  end

  def create
    api_key_params = params.require(:api_key).permit(:provider, :name, :secret)

    @api_key = ApiKey.new(api_key_params)

    if @api_key.save
      redirect_to settings_path, notice: "API Key created successfully."
    else
      render :new, status: 422
    end
  end

  def edit
    @api_key = ApiKey.find(params[:id])
  end

  def update
    @api_key = ApiKey.find(params[:id])

    api_key_params = params.require(:api_key).permit(:name, :secret)

    if @api_key.update(api_key_params)
      redirect_to settings_path, notice: "API Key updated successfully."
    else
      render :edit, status: 422
    end
  end

  def destroy
    @api_key = ApiKey.find(params[:id])

    @api_key.destroy

    redirect_to settings_path, notice: "API Key deleted successfully."
  end
end