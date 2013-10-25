Redmine::Plugin.register :redmine_zulip do
    name 'Zulip'
    author 'Zulip, Inc.'
    description 'Sends notifications to Zulip.'
    version '0.91'
    url 'https://github.com/zulip/zulip-redmine-plugin'
    author_url 'https://www.zulip.com/'

    Rails.configuration.to_prepare do
        require_dependency 'zulip_hooks'
        require_dependency 'zulip_view_hooks'
        require_dependency 'project_patch'
        Project.send(:include, RedmineZulip::Patches::ProjectPatch)
    end

    settings :partial => 'settings/redmine_zulip',
             :default => {
             :zulip_email => "",
             :zulip_api_key => "",
             :zulip_stream => ""}
end
