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

# configuration

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  @files = Dir.glob("data/*").map do |path|
    File.basename(path)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../tests/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_user_list
  user_list = YAML.load(File.open('users.yml'))
  users_array = []
  user_list.each do |k, v|
    users_array << [k, BCrypt::Password.new(v)]
  end
  users_array
end

def signed_in?
  session[:user].nil?
end

def redirect_to_login?
  if signed_in?
    session[:error] = "You must be signed in to do that."
    redirect "/"
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

def fulljs_present?
  @page.css("full.js").first
end

def get_meta_attributes(page)
  meta = {}
  meta[:title] = page.css('head>title').text || page.css('head>meta[@name=title')
  meta[:description] = page.xpath("//meta[@name='description']/@content")
  meta[:description] ||= page.css('head>description').text
  return meta
end

helpers do
  def paragraphify(text)
    text.gsub("\n", "<br />")
  end

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

  def valid_filetype?(filename)
    %w(txt md).include? filename.split(".").last
  end

  def filename_taken?(filename)
    @files.include? filename
  end

  def valid_filename?(filename)
    filename.strip.length > 0 && !filename_taken?(filename) && valid_filetype?(filename)
  end
end

# routes

get "/" do
  erb :index, layout: :layout
end

post "/get" do
  session[:url] = params[:url]
  check_protocol(params[:url])
  redirect "/result"
end

get "/result" do
  @url = session[:url]
  @page = Nokogiri::HTML(open(@url))
  @meta = get_meta_attributes(@page)
  erb :result, layout: :layout
end

get "/read/*.*" do |path, ext|
  filename = path
  filetype = ext
  filepath = File.join(data_path,"#{filename}.#{filetype}")
  if File.exist?(filepath)
    case filetype
    when 'txt'
      content_type :text
      File.read(filepath)
    when 'md'
      render_markdown(File.read(filepath))
    end
  else
    session[:error] = "#{filename}.#{filetype} does not exist."
    redirect "/"
  end
end

get "/edit/:file" do
  redirect_to_login?
  @filename = params[:file]
  filepath = File.join(data_path,@filename)
  @contents = File.read(filepath)
  erb :edit, layout: :layout
end

post "/edit/:file" do
  redirect_to_login?
  filename = params[:file]
  filepath = File.join(data_path,filename)
  new_contents = params[:contents]
  rewrite_file = File.open(filepath, "w") do |file|
    file.write new_contents
  end
  if rewrite_file
    session[:messages] = "#{filename} updated."
    redirect "/"
  else
    session[:error] = "There was an error updating #{filename}."
  end
end

get "/new" do
  redirect_to_login?
  erb :new, layout: :layout
end

post "/new" do
  redirect_to_login?
  filename = params[:filename]
  if valid_filename?(filename)
    f = File.new("data/#{filename}", "w")
    redirect "/"
  else
    session[:error] = "#{filename} is not a valid filename."
    redirect "/new"
  end
end

post "/delete/:filename" do
  redirect_to_login?
  filename = params[:filename]
  filepath = File.join(data_path,filename)
  File.delete(filepath)
  session[:messages] = "#{filename} has been deleted."
  redirect "/"
end

get "/login" do
  @username = session[:attempted_username]
  erb :login, layout: :layout
end

post "/login" do
  credentials = [params[:username], params[:password]]
  if load_user_list.include? credentials
    session[:user] = params[:username]
    session[:messages] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Invalid Credentials"
    session[:attempted_username] = params[:username]
    redirect "/login"
  end
end

get "/logout" do
  session.delete(:user)
  session.delete(:attempted_username)
  session[:messages] = "You have been logged out."
  redirect "/"
end

