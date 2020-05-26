#!/usr/bin/env ruby
#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

require File.dirname(__FILE__) + '/../../config/environment.rb'
require 'net/http'

LOREM_IPSUM = %{
  Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Donec accumsan, magna et venenatis semper, felis sem vestibulum erat, vitae iaculis magna ante sit amet mauris. Aliquam erat volutpat. Nam ultrices mi vitae risus. Vestibulum lorem. Pellentesque mauris turpis, auctor vitae, facilisis vel, aliquam ut, tortor. Duis in mi ut mi porttitor imperdiet. Quisque condimentum consectetuer justo. Maecenas dictum, arcu faucibus faucibus tempor, mi mi laoreet pede, a interdum dui lorem id risus. Sed posuere volutpat lacus. Phasellus aliquam rutrum dolor. Donec pulvinar. Cras volutpat est. Pellentesque tempor. Donec nec leo eu ipsum porta volutpat. Sed libero. Cras id nunc.

  Donec justo urna, tristique sed, tincidunt sed, euismod tempus, libero. Mauris neque libero, tempor eget, bibendum vehicula, eleifend et, felis. Nulla tempor dapibus urna. Etiam est urna, dignissim id, suscipit a, elementum et, velit. Vivamus sit amet lacus vel diam elementum aliquam. Fusce auctor leo. Integer ultricies cursus sem. Mauris a magna. Nam varius, urna vitae mattis consequat, leo eros scelerisque est, eu imperdiet lectus nulla in ante. In in libero.

  Aenean aliquam quam vitae dolor. Vestibulum commodo. Sed tellus lacus, dapibus non, consectetuer ut, dapibus id, mauris. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Morbi pulvinar. Mauris sagittis sagittis diam. Ut libero lectus, mollis a, bibendum non, laoreet sed, tellus. Integer consequat. Quisque nec nisl. Cras nunc. Nullam id nulla. Aenean pharetra fringilla est. Nam mollis viverra erat. Aenean vel quam nec felis tempor auctor. Curabitur sollicitudin. Ut turpis eros, tincidunt in, facilisis vel, dapibus ut, pede. Integer urna orci, tristique quis, varius ac, hendrerit vitae, sem. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos.

  Integer sit amet orci sed libero nonummy blandit. Maecenas leo. Vivamus semper, mi dictum dictum fermentum, leo lacus auctor eros, id mattis risus mi id tellus. Nulla facilisi. Vivamus euismod tristique velit. Donec ut enim. Duis malesuada velit eget orci venenatis varius. In ac ligula sit amet urna interdum pharetra. Praesent lacinia nisl in dolor. Morbi tempor lacus. Nam pulvinar nisl eget massa. Pellentesque imperdiet, lorem at vehicula feugiat, nibh ligula commodo tortor, id molestie libero neque id augue. Maecenas mollis.

  Duis mattis euismod sem. Maecenas sapien velit, commodo volutpat, consequat et, ullamcorper vel, odio. Praesent pharetra. Sed id ante molestie enim tempor pretium. Mauris risus orci, mattis non, semper a, mollis ac, metus. Donec ligula nulla, posuere sit amet, gravida ac, tincidunt et, eros. Aenean sapien justo, malesuada eu, molestie congue, nonummy at, dui. Quisque facilisis. Nunc eu leo. Vivamus lobortis arcu at massa. Duis ac eros sed est commodo imperdiet.

  Pellentesque sit amet sem. Vestibulum molestie ligula at leo. Suspendisse nec libero tincidunt nunc viverra consequat. Proin odio. Aliquam volutpat, risus eu pellentesque rhoncus, libero turpis adipiscing diam, fringilla consequat arcu elit vel libero. Maecenas id enim sit amet erat volutpat sollicitudin. Praesent at felis. Morbi laoreet, elit a sodales tristique, sapien leo hendrerit neque, id pharetra dolor purus pharetra tortor. Mauris ultrices feugiat augue. Praesent nec tellus in lectus rhoncus scelerisque. In convallis quam in quam.

  Proin augue lacus, tempor dignissim, vehicula eget, interdum aliquam, metus. Curabitur interdum adipiscing arcu. Donec rutrum interdum felis. Aliquam fermentum, quam ac dapibus sagittis, dui lectus sollicitudin ipsum, in tincidunt metus dui non neque. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Cras sit amet magna viverra urna convallis varius. Nullam enim. Aenean tellus nunc, ultricies nec, ultricies eget, aliquet sit amet, arcu. Nullam et lectus. Vestibulum sit amet risus a ante blandit volutpat. Curabitur facilisis neque sed augue. Curabitur id orci. Nullam volutpat dapibus odio.

  Praesent auctor. Sed faucibus, erat eget suscipit tempor, ligula nibh consequat arcu, id tristique leo erat ut nisi. Mauris ac diam. Aliquam sem nisl, semper eu, sollicitudin at, vulputate et, massa. Praesent pede. Aliquam nisi augue, vehicula vitae, imperdiet ac, interdum at, enim. Donec ac tellus. Curabitur ut sapien nec orci vulputate vulputate. Aenean blandit congue mauris. Integer dignissim viverra nisl. Quisque non velit ut velit tristique auctor.

  Pellentesque pulvinar, lectus sit amet elementum ultricies, nulla libero consequat nisi, et condimentum est risus vel dui. Ut dignissim sem vel lorem sagittis ultricies. In hac habitasse platea dictumst. Sed vitae libero. Vivamus et tellus. Vestibulum vitae augue id sem vehicula iaculis. Donec et velit. Nam eros mauris, consequat sed, convallis non, egestas non, velit. Ut euismod porta metus. Sed vitae nibh. Sed quis nunc id magna aliquet venenatis. Praesent in risus.

  Sed lacus. Suspendisse dictum, sem vel consequat imperdiet, dui nisi condimentum arcu, in viverra libero odio eu lacus. Proin fermentum porta massa. Cras leo. Suspendisse egestas felis et quam. Nam imperdiet. Vivamus interdum. Duis enim. Aliquam erat volutpat. Nulla arcu sapien, varius eu, placerat et, faucibus mollis, nisl. Curabitur libero erat, consectetuer ut, suscipit sed, gravida at, ipsum. In accumsan imperdiet quam. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Vivamus mollis orci tincidunt diam. Etiam accumsan purus ut nibh. Nam velit enim, dictum vitae, cursus sed, posuere vel, sapien. Aliquam vehicula luctus elit. Vivamus blandit tempor ante. Maecenas ornare varius lacus.

  Suspendisse dignissim sapien et erat. Vestibulum vestibulum eros sit amet tortor. Vivamus blandit aliquet lacus. Praesent pretium condimentum arcu. Quisque molestie vestibulum nulla. Vivamus tortor ligula, bibendum imperdiet, facilisis id, facilisis vel, metus. Aliquam eros. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Mauris vulputate. Curabitur vehicula faucibus lorem. Nullam egestas feugiat lorem. Cras condimentum rhoncus velit.

  Nunc sit amet pede. Suspendisse eros diam, hendrerit in, fringilla quis, lobortis ut, enim. Aenean non augue eu turpis lacinia blandit. Pellentesque placerat. Donec eget sem ut ante pharetra sodales. Quisque aliquet lobortis nibh. Mauris laoreet sapien in lectus. Proin at nulla quis metus viverra mattis. Pellentesque augue eros, laoreet quis, hendrerit ut, tempor placerat, lectus. Quisque purus. Mauris neque velit, vehicula ut, convallis nec, porta et, ante. In posuere scelerisque mi. Donec vehicula. Vestibulum nec est. Etiam augue nisi, scelerisque ut, eleifend volutpat, eleifend vitae, diam. Vestibulum urna. Integer aliquet posuere arcu. Integer dictum.

  Sed tincidunt libero at odio. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Curabitur vehicula auctor ligula. Etiam faucibus nunc at libero. Curabitur imperdiet suscipit lorem. Maecenas pede. Sed euismod vehicula lacus. Etiam euismod diam eget enim. In facilisis, urna ac bibendum consectetuer, leo pede rhoncus tortor, a ornare augue ante ac quam. Pellentesque commodo sagittis erat. Suspendisse potenti. Nam quis turpis. Sed nec sem. Aliquam faucibus. Maecenas ipsum lacus, consequat ac, luctus vitae, pretium ac, nulla. Nam tempor tristique ligula. Nulla facilisi. Donec ultricies. Nam molestie.

  Quisque sodales quam id ligula. Curabitur lacus nunc, vestibulum ac, fermentum at, ultrices quis, erat. Donec consequat ante id massa. Ut ac neque sit amet ante elementum pretium. Maecenas nunc odio, suscipit vel, blandit semper, auctor ac, ante. Vivamus porta mi quis nibh luctus vulputate. Mauris sodales dictum nunc. Duis imperdiet, neque a feugiat vestibulum, mi est vestibulum neque, eu auctor tortor diam eu velit. Phasellus aliquet, tortor et tristique molestie, leo enim aliquet dui, in consequat diam magna ac quam. Suspendisse facilisis magna faucibus leo. Integer ac nunc ut tellus dapibus lacinia. Fusce sagittis facilisis lectus. Vivamus aliquam. In fringilla hendrerit felis.

  Vivamus a mauris adipiscing felis ornare suscipit. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Phasellus ligula nunc, rutrum non, tempus at, consequat sit amet, lorem. Pellentesque ultrices dui et neque. Vivamus adipiscing ante eget tortor mattis placerat. Praesent aliquet. In mattis dolor at velit. Mauris ullamcorper sapien sit amet ligula. Quisque eu velit ultrices odio placerat dapibus. Sed suscipit urna vitae sapien. Nulla a eros quis urna tempus pretium. Aliquam erat volutpat. Quisque lacinia sem at tellus. Vestibulum mattis iaculis sapien. Pellentesque sed orci. Vivamus ac lacus vitae eros lacinia pellentesque. Donec porta lobortis augue. Maecenas vitae mi eu lectus adipiscing vehicula. Vestibulum nonummy libero.

  Integer aliquet ipsum nec ante. Sed semper sem eu odio. Sed in ligula. Nullam luctus posuere lorem. Proin lacinia. Vestibulum nunc. Praesent luctus diam nec nisl. Vestibulum bibendum nisi sit amet risus. Aliquam ullamcorper nisi ac urna. Ut magna. Sed blandit ipsum ut diam. Maecenas mattis diam quis leo. Ut mattis adipiscing odio. Praesent ultricies. Cras sollicitudin. Mauris ac lorem. Vestibulum ultrices, enim nec vulputate sollicitudin, dolor tortor volutpat metus, ut faucibus neque lorem sed diam. Vestibulum mauris dui, posuere aliquet, eleifend ut, accumsan eget, velit.

  Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; In lorem velit, lobortis eu, fermentum id, convallis vitae, nibh. Vestibulum faucibus metus euismod magna. Suspendisse potenti. Nulla facilisi. Suspendisse dapibus. Cras fringilla mattis tortor. Maecenas at nulla ut justo adipiscing commodo. Vestibulum nibh neque, scelerisque eget, sodales nec, dictum a, quam. Aliquam hendrerit, mi in sagittis congue, quam enim rhoncus orci, vitae adipiscing mauris lacus vel libero.

  Ut porta bibendum massa. Phasellus quis lacus sit amet sem accumsan aliquet. Mauris sem. Sed sit amet metus. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Sed nec dui in nunc malesuada consequat. Curabitur elementum, mi sed porta sollicitudin, ante purus faucibus massa, ut lacinia libero mi eu leo. Aenean dictum. In mollis blandit velit. Ut libero ante, congue sed, consequat vel, rhoncus commodo, turpis. Sed risus neque, aliquet laoreet, bibendum nec, posuere nec, orci. Nunc metus turpis, euismod mattis, ultrices ac, viverra quis, purus. Nam sed pede sit amet quam ultricies pulvinar. Ut nisi.

  Nulla nec mauris a enim euismod dapibus. Aliquam luctus egestas ante. Etiam leo ipsum, posuere ut, porta at, aliquam aliquam, dolor. Donec egestas sollicitudin urna. Quisque nec massa et eros nonummy volutpat. Suspendisse felis nisi, interdum ac, scelerisque ac, dictum nec, sem. Curabitur ultricies, tortor nec rhoncus malesuada, lorem diam gravida risus, nec iaculis nunc felis id purus. Nunc aliquam, mi ut luctus iaculis, est enim ornare magna, at porttitor magna mi sed magna. Aliquam dui arcu, vestibulum nec, dictum nec, tincidunt ac, quam. Quisque pellentesque, purus a tempus convallis, erat ipsum tristique diam, sed convallis nulla tellus id quam. Quisque enim nulla, nonummy id, commodo condimentum, cursus nec, ante. Donec at turpis at urna pellentesque vestibulum. Pellentesque est tellus, tincidunt vel, lacinia nec, dapibus sed, massa. Proin quis nisl at turpis luctus ultrices. Praesent dolor lectus, gravida id, pretium sit amet, commodo vel, nulla. Duis tempor commodo justo. In nec lectus.

  Cras condimentum auctor ipsum. Vivamus leo. Vestibulum sapien quam, venenatis et, ornare vitae, rutrum sed, magna. Suspendisse eget orci. Fusce egestas. Vestibulum eu felis. Vivamus id lectus. Nunc sem massa, scelerisque sed, eleifend ut, interdum vitae, ipsum. Morbi eget sapien. Fusce leo. Donec nulla. Sed rutrum porta nibh.
}

class Runner
  def initialize
    yield(self)
    run
  end
  
  attr_accessor :users, :repeat, :duration

  def []=(project_name, *actions)
    transactions_to_perform[project_name] = *actions
  end  

  def transactions_to_perform
    @transactions_to_perform ||= {}
  end
  
  def run
    users.each do |user|
      fork do
        until false do
          transactions_to_perform.each do |project, requests|
            requests.each { |req| req.perform(project, user) }
          end  
        end 
      end
    end
    Process.waitall
  end  
end

class TimedCondition
  
  def initialize(duration, start_time=Time.now)
    @start_time = start_time
    @duration = duration
  end  
  
  def stop?(user)
    return false if @duration == :forever
    (Time.now - @start_time) > @duration
  end
  
end  

class RepetitionCondition
  
  def initialize(repeat_count)
    @repeat_count = repeat_count
    @executions = {}
  end  
  
  def stop?(user)
    return false if @repeat_count == :forever
    @executions[user] ||= 0
    @executions[user] += 1
    @executions[user] == @repeat_count
  end
  
end  

class Request
  
  attr_accessor :project, :user

  def set_credentials(project, user)
    self.project = Project.find_by_identifier(project)
    self.user = user
  end  
  
  def follow_redirects(response, limit=10)
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0
    case response
    when Net::HTTPSuccess     then response.body
    when Net::HTTPRedirection then GetRequest.new(response['location']).perform(project.identifier, user, limit - 1);
    else
      puts response.body
      response.error!
    end
  end
  
  def request_url_with_credentials(relative_path, query_params = {})
    "http://#{user}:p@localhost:8080/projects/#{project.identifier}/#{relative_path}?#{query_params.to_query}".gsub(/\[\]/) { |m| '%5B%5D' } #hack to remove []
  end  
  
  def random_string
    max = ::LOREM_IPSUM.length
    LOREM_IPSUM[0..rand(max)]
  end
end  

class GetRequest < Request
  attr_accessor :url, :relative_url, :query_params
  
  def initialize(relative_url, query_params={})
    self.relative_url = relative_url
    self.query_params = query_params
  end  
  
  def perform(project, user, limit=10)
    if limit == 10
      set_credentials(project, user)
      self.url = request_url_with_credentials(relative_url, query_params)
    else #it is a redirect
      self.url = URI.parse(relative_url)
      self.url.user = user
      self.url.password = 'p'
      self.url = self.url.to_s
    end
    `curl '#{url}'`
  end  
end

class RandomCardUpdate < Request

  def card
    card_ids = self.project.cards.collect(&:id)
    random_card_id = card_ids[rand(card_ids.size)]
    self.project.cards.find(random_card_id)
  end  

  def perform(project, user)
    set_credentials(project, user)
    self.project.with_active_project do |p|
      post_url = URI.parse(request_url_with_credentials("cards/update/#{card.id}"))
      params = card.attributes.dup.merge('description' => random_string).inject({}) do |result, attr_name_value_pair|
        attribute_name = attr_name_value_pair.first
        next result if (['id', 'number', 'version', 'has_macros'].include?(attribute_name.to_s) || attribute_name.to_s =~ /(^cp)|(_at$)|(_id$)/)
        result["card[#{attribute_name}]"] = attr_name_value_pair.last
        result
      end
      follow_redirects(Net::HTTP.post_form(post_url, params), 10)
    end  
  end
end

class FailingRandomCardUpdate < Request

  def card
    card_ids = self.project.cards.collect(&:id)
    random_card_id = card_ids[rand(card_ids.size)]
    self.project.cards.find(random_card_id)
  end  

  def perform(project, user)
    set_credentials(project, user)
    begin
      self.project.with_active_project do |p|
        post_url = URI.parse(request_url_with_credentials("cards/update/#{card.id}"))
        params = card.attributes.dup.merge('description' => random_string).inject({}) do |result, attr_name_value_pair|
          attribute_name = attr_name_value_pair.first
          result["card[#{attribute_name}]"] = attr_name_value_pair.last
          result["card[number]"] = 999999999999999999
          result
        end
        follow_redirects(Net::HTTP.post_form(post_url, params), 10)
      end
    rescue Exception => e
      #Ignore!! I want this to happen - but not kill the test
    end    
  end
end

class CloneOverviewPageRequest < Request
  
  def perform(project, user)
    set_credentials(project, user)
    self.project.with_active_project do |p|
      existing_overview_clones = p.pages.count { |page| page.name =~ /verview/ }
      next_overview_clone_name = "Overview #{existing_overview_clones + 1}"
      post_url = URI.parse(request_url_with_credentials("wiki/Overview_#{existing_overview_clones + 1}/create"))
      params = {'page[content]' => p.overview_page.content, 'page[name]' => next_overview_clone_name, 'pagename' => next_overview_clone_name, 'attachments[0]' => ''}
      follow_redirects(Net::HTTP.post_form(post_url, params), 10)
    end  
  end
  
end

class ReadRandomWikiPageRequest < Request
  
  def perform(project, user)
    set_credentials(project, user)
    self.project.with_active_project do |p|
      existing_overview_clones = p.pages.count { |page| page.name =~ /verview/ }
      random_overview_clone_page = (1..existing_overview_clones).to_a[rand(existing_overview_clones)]
      random_overview_clone_identifier = "Overview_#{random_overview_clone_page}"
      ::GetRequest.new("wiki/#{random_overview_clone_identifier}").perform(project, user)
    end  
  end
  
end  

class ShowRandomCard < Request
  def perform(project, user)
    set_credentials(project, user)
    self.project.with_active_project do |p|
      existing_card_numbers = ActiveRecord::Base.connection.select_values("SELECT number from #{Card.table_name} ORDER BY number")
      random_card_number = existing_card_numbers[rand(existing_card_numbers.size)]
      ::GetRequest.new("cards/show/#{random_card_number}").perform(project, user)
    end  
  end
end  

class PropertyRename < Request
 attr_accessor :property

 def initialize(property_name)
   self.property = self.project.property_definitions.find_by_name(property_name) || self.project.property_definitions.first
 end

 def perform(project, user)
   set_credentials(project, user)
   self.project.with_active_project do |p|
     post_url = URI.parse(request_url_with_credentials("property_definitions/update/#{property.id}"))
     params = property.attributes.dup.merge('name' => 
random_string[0..10]).inject({}) do |result,attr_name_value_pair|
       result["property[#{attr_name_value_pair.first}]"] = attr_name_value_pair.last
       result
     end
     follow_redirects(Net::HTTP.post_form(post_url, params), 10)
   end
 end
end
