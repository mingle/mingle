module DocumentationTestHelper
  def build_help_link(feature)
    sprintf("%s/help/%s", MingleConfiguration.site_url, feature)
  end
end
