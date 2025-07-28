module ApplicationHelper
  # rubocop:disable Layout/LineLength
  def sorted_talos_versions
    # ["v1.8.1", "v1.8.2", "v1.9.0", ...]
    available_versions = TalosImageFactory.available_versions
    alpha_beta_versions, regular_versions = available_versions.partition do |version|
      version.include?("beta") || version.include?("alpha")
    end
    regular_versions.sort! do |a, b|
      Gem::Version.new(b.delete_prefix("v")) <=> Gem::Version.new(a.delete_prefix("v"))
    end

    regular_versions + alpha_beta_versions
  end

  def pretty_api_key_provider(provider)
    icon = image_tag "provider_icons/#{provider}.png", class: "inline h-[18px] mr-2"
    label = provider.titleize

    "#{icon} #{label}".html_safe
  end

  # Goal here is to avoid bloating the width of the Model column in the servers table
  def pretty_product(product)
    # eg. Dell PowerEdge™ R6615 DX182
    return product.split.last if product.start_with?("Dell")

    # Most products don't need this but it cleans up eg. AX41-NVMe
    product.split("-").first
  end

  def icon_close
    %(
      <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
      </svg>
    ).html_safe
  end

  # From a predefined shape in https://mediamodifier.com/svg-editor
  def icon_onboarding_arrow(klass)
    %(
      <svg class="#{klass}" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 76.394 64.018">
        <path
          d="M36.285 55.915
            L76.394 32.754
            L43.642 0
            L43.642 15.657
            C7.158 13.967 0 34.941 3.48 64.018
            C9.347 43.689 20.627 32.705 39.765 35.389
            L36.285 55.915
            Z"
          fill="#bfdbfe"
          fill-rule="nonzero"
        />
      </svg>
    ).html_safe
  end

  # https://heroicons.com/
  def icon_edit
    %(<svg class="inline h-[18px]" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" /></svg>).html_safe
  end

  def icon_cross
    %(<svg class="h-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>).html_safe
  end

  def icon_checkmark
    %(<svg class="w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg>).html_safe
  end

  def icon_alert
    %(<svg class="h-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" /></svg>).html_safe
  end

  def icon_reload
    %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99" /></svg>).html_safe
  end

  def icon_trash(classes = "h-full")
    %(<svg class="#{classes}" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" /></svg>).html_safe
  end

  def icon_download(classes = "h-full")
    %(<svg class="#{classes}" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" /></svg>).html_safe
  end

  def icon_ellipsis_horisontal
    %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" d="M6.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0zM12.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0zM18.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0z" /></svg>).html_safe
  end

  def icon_ellipsis_vertical
    %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 6.75a.75.75 0 110-1.5.75.75 0 010 1.5zM12 12.75a.75.75 0 110-1.5.75.75 0 010 1.5zM12 18.75a.75.75 0 110-1.5.75.75 0 010 1.5z" /></svg>).html_safe
  end
  # rubocop:enable Layout/LineLength
end
