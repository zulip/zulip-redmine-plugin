class AddZulipServerSettingsToProjects < ActiveRecord::Migration[5.2]
  def change
    add_column :projects, :zulip_url,     :string
    add_column :projects, :zulip_email,   :string
    add_column :projects, :zulip_api_key, :string
  end
end
