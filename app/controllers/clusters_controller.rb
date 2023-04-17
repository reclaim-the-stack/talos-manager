class ClustersController < ApplicationController
  def index
    @clusters = Cluster.all
  end

  def new
    @cluster = Cluster.new
  end

  def create
    cluster_params = params.require(:cluster).permit(:name, :endpoint, :secrets, :hetzner_vswitch_id)

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

    cluster_params = params.require(:cluster).permit(:name, :endpoint, :secrets, :hetzner_vswitch_id)

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

  def talosconfig
    @cluster = Cluster.find(params[:id])

    first_control_plane = @cluster.servers
      .where.associated(:machine_config)
      .where("name ILIKE '%control-plane%'")
      .order(name: :asc)
      .first

    if first_control_plane
      talosconfig = first_control_plane.machine_config.generate_config(output_type: "talosconfig")

      headers["Content-Type"] = "text/yaml"
      render plain: talosconfig
    else
      redirect_to clusters_path, alert: "Can't generate talosconfig without a control plane server configured!"
    end
  end

  def kubeconfig
    @cluster = Cluster.find(params[:id])

    first_control_plane = @cluster.servers
      .where.associated(:machine_config)
      .where("name ILIKE '%control-plane%'")
      .order(name: :asc)
      .first

    if first_control_plane
      talosconfig_path = "#{Dir.tmpdir}/#{SecureRandom.hex}"
      kubeconfig_path = "#{Dir.tmpdir}/#{SecureRandom.hex}"

      File.write talosconfig_path, first_control_plane.machine_config.generate_config(output_type: "talosconfig")
      system("talosctl --talosconfig #{talosconfig_path} -n #{first_control_plane.ip} kubeconfig #{kubeconfig_path}")
      kubeconfig = File.read(kubeconfig_path)

      headers["Content-Type"] = "text/yaml"
      render plain: kubeconfig
    else
      redirect_to clusters_path, alert: "Can't generate kubeconfig without a control plane server configured!"
    end
  end
end
