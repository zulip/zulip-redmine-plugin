module RedmineZulip
  module ProjectPatch
    extend ActiveSupport::Concern

    included do
      safe_attributes(
        "zulip_url",
        "zulip_email",
        "zulip_api_key",
        "zulip_stream_pattern",
        "zulip_issue_updates_subject_pattern",
        "zulip_version_updates_subject_pattern",
      )
    end
  end
end
