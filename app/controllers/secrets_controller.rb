class SecretsController < ApplicationController
  def index
    @secrets = Secret.all
  end

  def new
    @secret = Secret.new
  end

  def create
    secret_params = params.require(:secret).permit(:name, :secrets)

    @secret = Secret.new(secret_params)

    if @secret.save
      redirect_to secrets_path
    else
      render :new, status: 422
    end
  end

  def edit
    @secret = Secret.find(params[:id])
  end

  def update
    @secret = Secret.find(params[:id])

    secret_params = params.require(:secret).permit(:name, :secrets)

    if @secret.update(secret_params)
      redirect_to secrets_path
    else
      render :edit, status: 422
    end
  end

  def destroy
    Secret.find(params[:id]).destroy

    redirect_to secrets_path
  end
end
