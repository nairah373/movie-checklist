Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :movies, only: [:index, :create, :destroy] do
    member do
      patch :toggle
    end
    collection do
      post   :seed
      delete :clear
    end
  end

  root "movies#index"
end
