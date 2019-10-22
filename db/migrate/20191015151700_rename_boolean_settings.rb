class RenameBooleanSettings < ActiveRecord::Migration[5.2]
  def change
    rename_column :projects, :zulip_subject_issue,   :zulip_issue_updates
    rename_column :projects, :zulip_subject_version, :zulip_version_updates
  end
end
