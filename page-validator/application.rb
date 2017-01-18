require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"
require "nokogiri"
require "open-uri"
require "cgi"
require "capybara"
require "capybara/poltergeist"
require "capybara/dsl"
require "uri"

# configuration

include Capybara::DSL
Capybara.default_driver = :poltergeist

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {js_errors: false})
end

UI_JS_VALUES = [
  URI("http://ui.powerreviews.com/stable/4.0/ui.js"),
  URI("https://ui.powerreviews.com/stable/4.0/ui.js")
  ]

configure do
  enable :sessions
  enable :logging
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  @loaded_elements ||= {}
  @pr_elements ||= []
end

def get_network_traffic(page)
  visit(page)
  page.driver.network_traffic.each do |request|
    request.response_parts.each do |response|
      @loaded_elements[response.url] = response.status
    end
  end
end

def get_powerreviews_files
  @loaded_elements.each do |k, v|
    url = URI(k)
    #puts url.path.to_s.split('/').last
    if url.host =~ /powerreviews.com/i
      @pr_elements << url
    end
  end
end

def check_protocol(url)
  if url =~ /^(https?:\/\/)/
    redirect "/result"
  else
    session[:error_header] = "Invalid URL"
    session[:error] = "Please copy the full URL, including http:// or https://"
    session.delete(:url)
    redirect "/"
  end
end

def get_meta_attributes(page)
  meta = {}
  meta[:title] = page.css('head>title').text || page.css('head>meta[@name=title')
  meta[:description] = page.xpath("//meta[@name='description']/@content")
  meta[:description] ||= page.css('head>description').text
  return meta
end

def get_filename(url)
end

def ui_js_present?(element_list = @pr_elements)
  element_list.any? { |resource| UI_JS_VALUES.include? resource }
  return element_list
end

def full_js_present?(element_list = @pr_elements)
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

helpers do
  def current_working_url
    if session[:url]
      session[:url]
    else
      "http://"
    end
  end

  def render_checkmark?(condition)
    if condition
      return "fa-check-circle-o"
    else
      return "fa-exclamation-circle"
    end
  end

  def render_markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(text)
  end
end

# routes

get "/" do
  erb :index, layout: :layout
end

post "/get" do
  session[:url] = params[:url]
  check_protocol(params[:url])
  get_network_traffic(params[:url])
  get_powerreviews_files

  redirect "/result"
end

get "/result" do
  @url = session[:url]
  @page = Nokogiri::HTML(open(@url))
  @meta = get_meta_attributes(@page)

  erb :result, layout: :layout
end


