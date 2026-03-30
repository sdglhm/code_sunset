module CodeSunset
  FeatureSnapshot = Struct.new(
    :feature,
    :last_seen_at,
    :hits_7d,
    :hits_30d,
    :unique_orgs_count,
    :unique_users_count,
    :paid_hits_30d,
    :status,
    :score,
    keyword_init: true
  )
end
