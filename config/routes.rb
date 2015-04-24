DiscourseAkismet::Engine.routes.draw do
  get '/' => 'akismet_stats#index'
  resource :akismet_stats
end
