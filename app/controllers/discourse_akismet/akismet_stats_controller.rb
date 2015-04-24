module DiscourseAkismet
  class AkismetStatsController < Admin::AdminController
    requires_plugin 'discourse-akismet'

    def index
    end

    def show
      render_json_dump(akismet_stat: {
        id: 'akismet',
        enabled: SiteSetting.akismet_enabled?,
        stats: DiscourseAkismet.stats
      })
    end
  end
end
