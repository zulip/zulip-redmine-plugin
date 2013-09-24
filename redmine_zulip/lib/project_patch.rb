module RedmineZulip
    module Patches
        module ProjectPatch
            def self.included(base)
                base.class_eval do
                    safe_attributes 'zulip_email', 'zulip_api_key', 'zulip_stream'
                end
            end
        end
    end
end
