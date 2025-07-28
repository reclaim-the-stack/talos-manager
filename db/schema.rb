# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_07_28_075647) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_keys", force: :cascade do |t|
    t.string "provider", null: false
    t.string "name", null: false
    t.string "secret", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_api_keys_on_name", unique: true
  end

  create_table "clusters", force: :cascade do |t|
    t.string "name", null: false
    t.string "endpoint", null: false
    t.text "secrets", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "hetzner_vswitch_id"
    t.index ["hetzner_vswitch_id"], name: "index_clusters_on_hetzner_vswitch_id"
  end

  create_table "configs", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "install_image", default: "ghcr.io/siderolabs/installer:v1.3.5", null: false
    t.string "kubernetes_version", default: "1.24.8", null: false
    t.text "patch"
    t.text "patch_control_plane"
    t.text "patch_worker"
    t.boolean "kubespan", default: false, null: false
    t.index ["name"], name: "index_configs_on_name", unique: true
  end

  create_table "hetzner_vswitches", force: :cascade do |t|
    t.string "name", null: false
    t.integer "vlan", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "label_and_taint_rules", force: :cascade do |t|
    t.string "match", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "labels"
    t.string "taints"
  end

  create_table "machine_configs", force: :cascade do |t|
    t.integer "config_id", null: false
    t.integer "server_id", null: false
    t.string "hostname", null: false
    t.string "private_ip", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "install_disk", default: "/dev/sda", null: false
    t.index ["config_id"], name: "index_machine_configs_on_config_id"
    t.index ["server_id"], name: "index_machine_configs_on_server_id"
  end

  create_table "servers", force: :cascade do |t|
    t.string "name"
    t.string "ip", null: false
    t.string "ipv6", null: false
    t.string "product", null: false
    t.string "data_center", null: false
    t.string "status", null: false
    t.boolean "cancelled", default: false, null: false
    t.integer "hetzner_vswitch_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "accessible", default: false, null: false
    t.string "uuid"
    t.datetime "last_configured_at"
    t.datetime "last_request_for_configuration_at"
    t.bigint "cluster_id"
    t.string "type", default: "Server::HetznerDedicated", null: false
    t.string "bootstrap_disk"
    t.string "architecture", default: "amd64", null: false
    t.bigint "api_key_id", null: false
    t.string "bootstrap_disk_wwid"
    t.datetime "label_and_taint_job_completed_at"
    t.bigint "talos_image_factory_schematic_id"
    t.index ["api_key_id"], name: "index_servers_on_api_key_id"
    t.index ["cluster_id"], name: "index_servers_on_cluster_id"
    t.index ["hetzner_vswitch_id"], name: "index_servers_on_hetzner_vswitch_id"
    t.index ["ip"], name: "index_servers_on_ip", unique: true
    t.index ["talos_image_factory_schematic_id"], name: "index_servers_on_talos_image_factory_schematic_id"
    t.index ["type"], name: "index_servers_on_type"
  end

  create_table "talos_image_factory_schematics", force: :cascade do |t|
    t.string "name", null: false
    t.string "body", null: false
    t.string "schematic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_talos_image_factory_schematics_on_name", unique: true
  end

  create_table "talos_image_factory_settings", force: :cascade do |t|
    t.string "version", null: false
    t.string "schematic_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "clusters", "hetzner_vswitches"
  add_foreign_key "machine_configs", "configs"
  add_foreign_key "machine_configs", "servers"
  add_foreign_key "servers", "api_keys"
  add_foreign_key "servers", "clusters"
  add_foreign_key "servers", "hetzner_vswitches"
  add_foreign_key "servers", "talos_image_factory_schematics"
end
