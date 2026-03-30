module CodeSunset
  module ApplicationHelper
    def format_seen_at(timestamp)
      return "Never" unless timestamp

      time = timestamp.in_time_zone
      relative_time = if time > Time.current
        "just now"
      else
        "#{time_ago_in_words(time)} ago"
      end

      content_tag(
        :time,
        relative_time,
        class: "cs-time",
        datetime: time.iso8601,
        title: time.strftime("%Y-%m-%d %H:%M:%S %Z")
      )
    end

    def human_count(value)
      number_with_delimiter(value || 0)
    end

    def status_badge(status)
      content_tag(:span, status.to_s.tr("_", " ").titleize, class: "cs-badge cs-badge--#{status}")
    end

    def current_filter_value(key)
      filters[key]
    end

    def analytics_notice
      analytics_filters.raw_filter_notice
    end

    def filters_applied?
      filters.except(:page).values.any?(&:present?)
    end

    def sidebar_nav_link(label, path, icon:)
      classes = ["cs-nav__link"]
      classes << "is-active" if current_page?(path)

      link_to path, class: classes.join(" ") do
        safe_join(
          [
            content_tag(:span, sidebar_icon(icon), class: "cs-nav__icon"),
            content_tag(:span, label, class: "cs-nav__text")
          ]
        )
      end
    end

    def removal_score_badge(feature, snapshot, label: nil)
      label ||= format("%.1f", snapshot&.score.to_f)

      content_tag(
        :span,
        label,
        class: "cs-score cs-score--help",
        title: removal_score_tooltip(feature, snapshot)
      )
    end

    def removal_score_tooltip(feature, snapshot)
      return "Removal score is unavailable until usage has been analyzed." unless feature && snapshot

      calculator = CodeSunset::ScoreCalculator.new(feature: feature, snapshot: snapshot)
      breakdown = calculator.breakdown

      [
        "Removal score favors features that look safer to remove.",
        "Recency: #{format('%.1f', breakdown[:recency][:score])}/#{format('%.0f', breakdown[:recency][:max])} from #{breakdown[:recency][:detail]}",
        "Volume: #{format('%.1f', breakdown[:volume][:score])}/#{format('%.0f', breakdown[:volume][:max])} from #{breakdown[:volume][:detail]}",
        "Org breadth: #{format('%.1f', breakdown[:orgs][:score])}/#{format('%.0f', breakdown[:orgs][:max])} from #{breakdown[:orgs][:detail]}",
        "Paid usage: #{format('%.1f', breakdown[:paid_usage][:score])}/#{format('%.0f', breakdown[:paid_usage][:max])} from #{breakdown[:paid_usage][:detail]}",
        "Total: #{format('%.1f', calculator.score)}/100"
      ].join("\n")
    end

    def usage_chart(points)
      return content_tag(:p, "No usage data yet.", class: "cs-subtle") if points.blank?

      labels = points.keys.map { |day| day.strftime("%b %-d") }
      values = points.values.map(&:to_i)

      content_tag(:div, class: "cs-chart-shell") do
        content_tag(
          :canvas,
          nil,
          class: "cs-chart",
          role: "img",
          aria: { label: "Feature usage trend chart" },
          data: {
            code_sunset_usage_chart: true,
            labels: labels.to_json,
            values: values.to_json
          }
        )
      end
    end

    def pagination_link_for(feature, label, page:, current:, filters: {}, rel: nil)
      classes = ["cs-pagination__link"]
      classes << "is-active" if current

      link_to label, feature_path(feature.key, filters.merge(page: page)), class: classes.join(" "), rel: rel
    end

    def removal_prompt_path_for(feature)
      feature_path(feature.key, filters.merge(generate_removal_prompt: true))
    end

    def removal_prompt_reset_path_for(feature)
      feature_path(feature.key, filters.except(:page))
    end

    def filter_query_values(overrides = {})
      filters.except(:page).merge(overrides).reject { |_key, value| value.blank? }
    end

    def filter_path_for(path, values = filter_query_values)
      query_values = values.reject { |_key, value| value.blank? }
      return path if query_values.empty?

      "#{path}?#{query_values.to_query}"
    end

    def active_filter_chips_for(path)
      filters.except(:page).each_with_object([]) do |(key, value), chips|
        next if value.blank?

        chips << {
          key: key,
          label: filter_chip_label(key),
          value: filter_chip_value(key, value),
          clear_path: filter_path_for(path, filters.except(:page, key))
        }
      end
    end

    def render_filter_bar(form_url:, reset_url:, title: "Filters", copy: nil)
      render(
        "code_sunset/shared/filter_bar",
        form_url: form_url,
        reset_url: reset_url,
        title: title,
        copy: copy,
        filters_applied: filters_applied?,
        active_chips: active_filter_chips_for(reset_url)
      )
    end

    def advanced_filters_open?
      filters.values_at(:plan, :org_id, :user_id, :paid_only, :exclude_internal, *configured_custom_filter_keys).any?(&:present?)
    end

    def configured_custom_filters
      CodeSunset.configuration.custom_filters
    end

    def configured_custom_filter_keys
      configured_custom_filters.keys
    end

    def custom_filter_input_tag(key, definition)
      current_value = current_filter_value(key)

      case definition[:type].to_sym
      when :boolean
        select_tag key, options_for_select([["Any", nil], ["Yes", true], ["No", false]], current_value), include_blank: false
      when :select
        select_tag key, options_for_select([["Any", nil]] + Array(definition[:options]), current_value), include_blank: false
      else
        text_field_tag key, current_value, placeholder: definition[:placeholder]
      end
    end

    private

    def filter_chip_label(key)
      configured = configured_custom_filters[key.to_sym]
      return configured[:label] if configured

      {
        app_env: "Environment",
        plan: "Plan",
        org_id: "Org",
        user_id: "User",
        from: "From",
        to: "To",
        paid_only: "Paid",
        exclude_internal: "Internal"
      }.fetch(key.to_sym, key.to_s.humanize)
    end

    def filter_chip_value(key, value)
      configured = configured_custom_filters[key.to_sym]
      if configured
        return truthy_filter_label(value) if configured[:type].to_sym == :boolean

        if configured[:type].to_sym == :select && configured[:options].present?
          matched = configured[:options].find { |label, option_value| option_value.to_s == value.to_s }
          return matched.first if matched
        end

        return value
      end

      case key.to_sym
      when :paid_only
        truthy_filter_label(value)
      when :exclude_internal
        truthy_filter_label(value, truthy: "Excluded", falsey: "Included")
      else
        value
      end
    end

    def truthy_filter_label(value, truthy: "Yes", falsey: "No")
      ActiveModel::Type::Boolean.new.cast(value) ? truthy : falsey
    end

    def sidebar_icon(name)
      path =
        case name.to_sym
        when :dashboard
          "M3.75 4.5h6.75v6.75H3.75zm9.75 0h6.75v4.5H13.5zm0 7.5h6.75v8.25H13.5zm-9.75 2.25h6.75V20.25H3.75z"
        when :features
          "M4.5 6.75A2.25 2.25 0 0 1 6.75 4.5h10.5a2.25 2.25 0 0 1 2.25 2.25v10.5a2.25 2.25 0 0 1-2.25 2.25H6.75A2.25 2.25 0 0 1 4.5 17.25zm3 2.25h9m-9 3.75h9m-9 3.75h5.25"
        when :removal_queue
          "M9 3.75h6m-7.5 4.5h9m-10.5 4.5h12m-10.5 4.5h9"
        else
          "M4.5 12h15"
        end

      content_tag(:svg, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": "1.75", "stroke-linecap": "round", "stroke-linejoin": "round", aria: { hidden: true }) do
        content_tag(:path, nil, d: path)
      end
    end
  end
end
