class RemoveBooleanSettings < ActiveRecord::Migration
  def change
    remove_column :projects, :zulip_private_messages, :boolean
    remove_column :projects, :zulip_issue_updates,    :boolean
    remove_column :projects, :zulip_version_updates,  :boolean
  end
end
