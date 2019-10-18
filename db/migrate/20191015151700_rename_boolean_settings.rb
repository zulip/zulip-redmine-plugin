class RenameBooleanSettings < ActiveRecord::Migration
  def change
    rename_column :projects, :zulip_subject_issue,   :zulip_issue_updates
    rename_column :projects, :zulip_subject_version, :zulip_version_updates
  end
end
