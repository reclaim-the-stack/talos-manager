class TalosImageFactorySchematicsController < ApplicationController
  def index
    @talos_image_factory_schematics = TalosImageFactorySchematic.order(:id).all
  end

  def new
    @talos_image_factory_schematic = TalosImageFactorySchematic.new
  end

  def create
    talos_image_factory_schematic_params = params.expect(talos_image_factory_schematic: %i[name body])

    @talos_image_factory_schematic = TalosImageFactorySchematic.new(talos_image_factory_schematic_params)

    if @talos_image_factory_schematic.save
      redirect_to talos_image_factory_schematics_path, notice: "Talos Image Factory Schematic created successfully."
    else
      render :new, status: 422
    end
  end

  def edit
    @talos_image_factory_schematic = TalosImageFactorySchematic.find(params[:id])
  end

  def update
    @talos_image_factory_schematic = TalosImageFactorySchematic.find(params[:id])

    talos_image_factory_schematic_params = params.expect(talos_image_factory_schematic: %i[name body])

    if @talos_image_factory_schematic.update(talos_image_factory_schematic_params)
      redirect_to talos_image_factory_schematics_path, notice: "Talos Image Factory Schematic updated successfully."
    else
      render :edit, status: 422
    end
  end

  def destroy
    talos_image_factory_schematic = TalosImageFactorySchematic.find(params[:id])
    talos_image_factory_schematic.destroy

    redirect_to talos_image_factory_schematics_path, notice: "Talos Image Factory Schematic deleted successfully."
  end
end
