class AddSubjectsPatternSettings < ActiveRecord::Migration
  def change
    rename_column :projects, :zulip_stream, :zulip_stream_pattern
    add_column :projects, :zulip_issue_updates_subject_pattern,   :string
    add_column :projects, :zulip_version_updates_subject_pattern, :string
    execute "UPDATE projects SET zulip_issue_updates_subject_pattern = '${issue_subject}'"
    execute "UPDATE projects SET zulip_version_updates_subject_pattern = 'Version ${version_name}'"
  end
end
