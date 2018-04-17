require 'json'
require 'net/http'
require 'time'
require 'base64'
require 'uri'
require 'open-uri'

ENV["SSL_CERT_FILE"] = "./cacert.pem"
IMPORTED = './imported.json'

credentials = open('./credentials.json') do |io|
  JSON.load(io)
end

imported_articles = open(IMPORTED) do |io|
  JSON.load(io)
end

COOKIE_STR = credentials['COOKIE_STR']
ACCESS_TOKEN = credentials['ACCESS_TOKEN']
TEAM_DOMAIN = credentials['TEAM_DOMAIN']
GROUP_ID = credentials['GROUP_ID']
USER_IDS = credentials['USER_IDS']
USER_ETC = credentials['USER_ETC']
QIITA_TEAM = credentials['credentials']

BASE_URL       = URI.parse('https://api.docbase.io')
REQUEST_HEADER = {'X-DocBaseToken' => ACCESS_TOKEN, 'X-Api-Version' => 1, 'Content-Type' => 'application/json'}

def wait
  # 1時間に300回を超えるリクエストは無効のため待つ
  start_at = Time.now
  yield
  sleep_sec = [3600 / 300.0 - (Time.now - start_at), 0].max
  sleep(sleep_sec)
end

def post(request_path, data)
  http = Net::HTTP.new(BASE_URL.host, BASE_URL.port)
  http.use_ssl = BASE_URL.scheme == 'https'

  request = Net::HTTP::Post.new(request_path)
  request.body = data
  REQUEST_HEADER.each { |key, value| request.add_field(key, value) }

  response = http.request(request)
  response_body = JSON.parse(response.body)

  if response.code == '201'
    response_body
  else
    message = response_body['messages'].join("\n")
    puts "Error: #{message}"
    nil
  end
end

def postImage(name, src_url)
  payload = {
    name: 'image.png',
    content: Base64.strict_encode64(open(src_url, 'Cookie' => COOKIE_STR) .read)
  }.to_json

  rjson = nil
  wait do
    rjson = post("/teams/#{TEAM_DOMAIN}/attachments", payload)
  end
  if rjson
    rjson['url'] 
  else
    puts "Error: uploading error #{src_url}"
    nil
  end
end

Dir.glob('articles/*') do |item|
  if imported_articles.has_key?(item) then
    puts "Article: #{item} skip: => #{imported_articles[item]}"
    next
  end

  created_post = nil
  qiita_url = nil

  open(item, encoding: 'UTF-8') do |file|
    puts "Article: #{item}"
    article = JSON.parse(file.read)

    title = article['title']
    qiita_url = article['url']
    qiitaUid = article['user']['id']
    group = article['group']['name']
    docbaseUid = USER_IDS[qiitaUid] || USER_ETC
   
    body = article['body']
    body = body.gsub(/https?:\/\/#{QIITA_TEAM}.qiita.com\/files\/([0-9a-z\-.]+)/) do | qiita_image_url|
      docbaseImageUrl = postImage($1,qiita_image_url)
      puts "Image #{qiita_image_url} => #{$1} => #{docbaseImageUrl}"
      docbaseImageUrl
    end
    body = body.gsub(/^(#+)/, '\1 ')
    head = "> Qiita-team(#{group}): [#{title}](#{qiita_url}) by #{qiitaUid} \r\n \r\n"    
    body = head + body

    post_json = {
      title:  title,
      body:   body,
      tags:   article['tags'].map { |tag| tag['name'] },
      scope:  'group',
      published_at: article['created_at'],
      author_id: docbaseUid,
      groups: [GROUP_ID],
      draft:  false,
      notice: false,
    }.to_json

    print "Create post "
    wait do
      created_post = post("/teams/#{TEAM_DOMAIN}/posts", post_json)
      puts created_post['url'] if created_post
    end
    next unless created_post

    article['comments'].each do |comment|
      comment_json = {
        body: comment['body'],
        published_at: comment['created_at'],
        author_id: USER_IDS[comment['user']['id']] || USER_ETC,
        notice: false,
      }.to_json

      wait do
        print "Create comment to Post[#{created_post['id']}] "
        created_comment = post("/teams/#{TEAM_DOMAIN}/posts/#{created_post['id']}/comments", comment_json)
        puts 'Success' if created_comment
      end
    end

  end

  imported_articles[item] = {
    "qiita" => qiita_url,
    "docbase" => created_post['url']
  }

  open(IMPORTED, 'w') do |io|
    JSON.dump(imported_articles, io)
  end
end
