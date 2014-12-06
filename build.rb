require "csv"
require "json"

def severityOf(value)
  case value
  when /正常/
    return 0
  when /轻微/
    return 1
  when /严重/
    return 3
  end
end

def rangeOf(value)
  case value
  when /^([\d.]+)-([\d.]+)$/
    return {
      :gt => $1.to_f,
      :lte => $2.to_f
    }
  when />([\d.]+)/
    return {
      :gt => $1.to_f
    }
  end
end

def stdOf(row)
  if row["观察类状态-严重程度"].nil?
    return {
      :desc => row["读取类状态-严重程度"],
      :range => rangeOf(row["读取类状态-范围"]),
      :severity => severityOf(row["读取类状态-严重程度"])
    }
  else
    return { 
      :desc => row["观察类状态-状态"],
      :severity => severityOf(row["观察类状态-严重程度"])
    }
  end
end

def itemOf(row)
  item = {
    :name => row["点检内容"],
    :desc => row["点检提问"].strip,
    :stopCheck => row["点检条件"] =~ /停机/ ? true : false,
    :checkStd => {
      :name => row["点检标准"],
      :type => row["观察类状态-严重程度"].nil? ? "scalar" : "enum",
      :std => [
        stdOf(row)
      ]
    }
  }

  if row["观察类状态-严重程度"].nil?
    item[:checkStd][:unit] = row["读取类状态-单位"] 
    item[:checkStd][:input] = "m"
  end

  return item
end

spots = []
parts = []
subjects = []
subject = {}
pk = ""

CSV.foreach("./plan.csv", :headers => true) do |row|
  if row["设备型号"].nil?
    subject[:items].last[:checkStd][:std] << stdOf(row)
  else
    parts << row["点检部件"]
    spots << row["点检部位"]
    if row["点检项目"].eql? pk
      subject[:items] << itemOf(row)
    else
      pk = row["点检项目"]
      subjects << subject unless subject.empty?

      subject = {
       :name => row["点检项目"],
       :equipPart => row["点检部件"],
       :chkpt => row["设备型号"] + "巡检点",
       :spot => row["点检部位"],
       :items => [
         itemOf(row)
       ]
      }
    end
  end
end

subjects << subject unless subject.empty?

obj = {
  :equipModels => [
    {
      :name => "",
      :desc => "",
      :model => "",
      :manufacturer => "",
      :spots => spots.uniq,
      :parts => parts.uniq.map {|part| { :name => part} },
      :instances => []
    }
  ],
  :plans => [
    {
      :name => "",
      :desc => "",
      :startAt => "",
      :endAt => "",
      :status => "active",
      :author => "",
      :equips => [],
      :assignTo => "",
      :subjects => subjects
    }
  ]
}

puts obj.to_json
