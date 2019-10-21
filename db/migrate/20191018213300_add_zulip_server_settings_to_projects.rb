class AddZulipServerSettingsToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :zulip_url,     :string
    add_column :projects, :zulip_email,   :string
    add_column :projects, :zulip_api_key, :string
  end
end
