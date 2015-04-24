module Jobs
  class CheckForSpamPosts < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      return unless SiteSetting.akismet_enabled?
      return if SiteSetting.akismet_api_key.blank?

      # Users above TL0 are checked in batches
      DiscourseAkismet.check_for_spam(DiscourseAkismet.to_check)
    end
  end
end
