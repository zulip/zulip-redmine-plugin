module RedmineZulip
  module ProjectPatch
    extend ActiveSupport::Concern

    included do
      safe_attributes(
        "zulip_stream",
        "zulip_subject_issue",
        "zulip_subject_version",
        "zulip_private_messages"
      )
    end
  end
end
