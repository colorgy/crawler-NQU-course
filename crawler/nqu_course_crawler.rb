require 'crawler_rocks'
require 'json'
require 'pry'

class NationalQuemoyUniversityCrawler

	def initialize year: nil, term: nil, update_progress: nil, after_each: nil

		@year = year-1911
		@term = term
		@update_progress_proc = update_progress
		@after_each_proc = after_each


		@query_url = 'http://select1.nqu.edu.tw/kmkuas/perchk.jsp'
	end

	def courses
		@courses = []

		r = RestClient.post(@query_url, {
			"uid" => "guest",
			"pwd" => "123",
			})
		cookie = "JSESSIONID=#{r.cookies["JSESSIONID"]}"

		@query_url = "http://select1.nqu.edu.tw/kmkuas/ag_pro/ag304_01.jsp"
		r = RestClient.get(@query_url, {"Cookie" => cookie })
		doc = Nokogiri::HTML(r)

		dep = Hash[doc.css('select[name="unit_id"] option').map{|opt| [opt[:value],opt.text]}]
		dep.each do |dep_c, dep_n|

			@query_url = "http://select1.nqu.edu.tw/kmkuas/ag_pro/ag304_02.jsp"
			r = RestClient.post(@query_url, {
				"yms_year" => @year,
				"yms_sms" => @term,
				"unit_id" => dep_c,
				"unit_serch" => "%E6%9F%A5+%E8%A9%A2",
				}, {"Cookie" =>cookie })
			doc = Nokogiri::HTML(r)

			degree = Hash[doc.css('table tr:not(:first-child) td[style="font-size: 9pt;color:blue;"] div').map{|td| [td[:onclick].split('\'')[1], td.text]}]
			degree.each do |degree_c, degree_n|

				@query_url = "http://select1.nqu.edu.tw/kmkuas/ag_pro/ag304_03.jsp"
				r = RestClient.post(@query_url, {
					"arg01" => @year,
					"arg02" => @term,
					"arg" => degree_c,
					}, {"Cookie" =>cookie })
				doc = Nokogiri::HTML(r)

				next if doc.css('table')[0] == nil
				for tr in 0..doc.css('table')[0].css('tr:not(:first-child)').count - 1
					data = []
					for td in 0..doc.css('table')[0].css('tr:not(:first-child)')[tr].css('td').count - 1
						data[td] = doc.css('table')[0].css('tr:not(:first-child)')[tr].css('td')[td].text
					end

					course = {
						year: @year,
						term: @term,
						general_code: data[0],
						name: data[1],
						group: data[2],
						credits: data[3],
						hours: data[4],
						required: data[5],
						department_term: data[6],
						day: data[7],
						lecturer: data[8],
						location: data[9],
						note: data[10],
					}

					@after_each_proc.call(course: course) if @after_each_proc

					@courses << course
				end
			end
		end
	# binding.pry
		@courses
	end

end

crawler = NationalQuemoyUniversityCrawler.new(year: 2015, term: 1)
File.write('courses.json', JSON.pretty_generate(crawler.courses()))
