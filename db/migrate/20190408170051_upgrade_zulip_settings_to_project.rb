class UpgradeZulipSettingsToProject < ActiveRecord::Migration[4.2]
  def change
    remove_column :projects, :zulip_email, :string
    remove_column :projects, :zulip_api_key, :string
    add_column :projects, :zulip_private_messages, :boolean, null: false, default: false
    add_column :projects, :zulip_subject_issue, :boolean, null: false, default: false
    add_column :projects, :zulip_subject_version, :boolean, null: false, default: false
  end
end
