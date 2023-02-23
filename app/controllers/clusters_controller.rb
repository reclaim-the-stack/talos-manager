class ClustersController < ApplicationController
  def index
    @clusters = Cluster.all
  end

  def new
    @cluster = Cluster.new
  end

  def create
    cluster_params = params.require(:cluster).permit(:name, :endpoint, :secrets)

    @cluster = Cluster.new(cluster_params)

    if @cluster.save
      redirect_to clusters_path, notice: "Cluster #{@cluster.name} successfully created!"
    else
      render :new, status: 422
    end
  end

  def edit
    @cluster = Cluster.find(params[:id])
  end

  def update
    @cluster = Cluster.find(params[:id])

    cluster_params = params.require(:cluster).permit(:name, :endpoint, :secrets)

    if @cluster.update(cluster_params)
      redirect_to clusters_path, notice: "Cluster #{@cluster.name} successfully updated!"
    else
      render :edit, status: 422
    end
  end

  def destroy
    Cluster.find(params[:id]).destroy

    redirect_to clusters_path
  end
end
