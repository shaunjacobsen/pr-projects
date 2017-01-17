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

loaded_elements = {}

visit "http://www.sjacobsen.com/pr/cd4/index.html"

page.driver.network_traffic.each do |request|
  request.response_parts.uniq(&:url).each do |response|
    loaded_elements[response.url] = response.status
    #puts "#{response.url}: #{response.status}"
  end
end

loaded_elements.each do |k, v|
  url = URI(k)
  puts url.path if url.host == "ui.powerreviews.com"
end