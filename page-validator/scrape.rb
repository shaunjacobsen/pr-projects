require 'capybara'
require 'capybara/poltergeist'
require 'capybara/dsl'
require 'uri'
require 'pry'

include Capybara::DSL
Capybara.default_driver = :poltergeist

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {js_errors: false})
end

UI_JS_VALUES = [
  URI("http://ui.powerreviews.com/stable/4.0/ui.js"),
  URI("https://ui.powerreviews.com/stable/4.0/ui.js")
  ]

FULL_JS_VALUES = [
  
]

@loaded_elements = {}
@pr_elements = []

visit "http://www.sjacobsen.com/pr/cd4/index.html"

page.driver.network_traffic.each do |request|
  request.response_parts.each do |response|
    @loaded_elements[response.url] = response.status
    #puts "#{response.url}: #{response.status}"
  end
end

@loaded_elements.each do |k, v|
  url = URI(k)
  #puts url.path.to_s.split('/').last
  if url.host =~ /powerreviews.com/i
    @pr_elements << url
  end
end

@pr_elements.each do |element|
  if element.path.split('/').last == "v1.gif"
    element.query.split('&')
  end
end

def get_filename(url)
end

def ui_js_present?(element_list)
  element_list.any? { |resource| UI_JS_VALUES.include? resource }
end

def full_js_present?(element_list)
  file_location = ""
  element_list.each do |resource|
    if (resource.host == "cdn.powerreviews.com" && resource.path.to_s.split('/').last == "full.js")
      file_location = "CDN"
    end
  end
  file_location == "CDN"
end

def external_full_js_present?(element_list)

end

def all_conditions_listing
  ui_js_present?(@pr_elements) ? "ui.js present" : "ui.js not present"
  full_js_present?(@pr_elements) ? "full.js present" : "full.js not present"
end

puts all_conditions_listing