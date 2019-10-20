module RedmineZulip
  class Settings
    def initialize(issue)
      @issue = issue
    end

    def enabled?
      zulip_url.present? && zulip_email.present? && zulip_api_key.present?
    end

    def zulip_url
      @issue.project.zulip_url.present? ?
        @issue.project.zulip_url : Setting.plugin_redmine_zulip["zulip_url"]
    end

    def zulip_email
      @issue.project.zulip_email.present? ?
        @issue.project.zulip_email : Setting.plugin_redmine_zulip["zulip_email"]
    end

    def zulip_api_key
      @issue.project.zulip_api_key.present? ?
        @issue.project.zulip_api_key :
        Setting.plugin_redmine_zulip["zulip_api_key"]
    end

    def stream
      replace_pattern(
        @issue.project.zulip_stream_pattern.present? ?
          @issue.project.zulip_stream_pattern :
          Setting.plugin_redmine_zulip["zulip_stream_pattern"]
      )
    end

    def issue_updates_subject
      replace_pattern(
        @issue.project.zulip_issue_updates_subject_pattern.present? ?
          @issue.project.zulip_issue_updates_subject_pattern :
          Setting.plugin_redmine_zulip["zulip_issue_updates_subject_pattern"]
      )
    end

    def version_updates_subject
      replace_pattern(
        @issue.project.zulip_version_updates_subject_pattern.present? ?
          @issue.project.zulip_version_updates_subject_pattern :
          Setting.plugin_redmine_zulip["zulip_version_updates_subject_pattern"]
      )
    end

    private

    def replace_pattern(pattern)
      return nil if pattern.nil?
      pattern.gsub("${issue_id}", "#{@issue.id}")
             .gsub("${issue_subject}", @issue.subject_without_punctuation)
             .gsub("${project_name}", @issue.project.name)
             .gsub("${version_name}",
                    @issue.fixed_version.nil? ? "" : @issue.fixed_version.name)
    end
  end
end
