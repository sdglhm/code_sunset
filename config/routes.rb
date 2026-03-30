CodeSunset::Engine.routes.draw do
  root to: "dashboard#index"
  resources :features, only: [:index, :show], constraints: { id: /[^\/]+/ }
  resources :removal_candidates, only: [:index]
end
