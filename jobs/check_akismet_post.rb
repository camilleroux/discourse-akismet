module Jobs
  class CheckAkismetPost < ::Jobs::Scheduled

    def execute(args)
      return unless SiteSetting.akismet_enabled?
      return if SiteSetting.akismet_api_key.blank?

      # Users above TL0 are checked in batches
      DiscourseAkismet.check_for_spam(DiscourseAkismet.to_check.where(id: args[:queued_post_id]))
    end
  end
end

