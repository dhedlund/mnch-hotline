class ReportController < ApplicationController

  include PdfHelper

  def weekly_report
    @start_date = Date.new(params[:start_year].to_i,params[:start_month].to_i,params[:start_day].to_i) rescue nil
    @end_date = Date.new(params[:end_year].to_i,params[:end_month].to_i,params[:end_day].to_i) rescue nil
    if @start_date > @end_date
      flash[:notice] = 'Start date is greater that end date'
      redirect_to :action => 'select'
      return
    end
    @diagnoses = ConceptName.find(:all,
                                  :joins =>
                                        "INNER JOIN obs ON
                                         concept_name.concept_id = obs.value_coded AND obs.voided = 0",
                                  :conditions => ["date_format(obs_datetime, '%Y-%m-%d') >= ? AND date_format(obs_datetime, '%Y-%m-%d') <= ?",
                                            @start_date, @end_date],
                                  :group =>   "name",
                                  :select => "concept_name.concept_id,concept_name.name,obs.value_coded,obs.obs_datetime,obs.voided")
    @patient = Person.find(:all,
                           :joins => 
                                "INNER JOIN obs ON 
                                 person.person_id = obs.person_id AND obs.voided = 0",
                           :conditions => ["date_format(obs_datetime, '%Y-%m-%d') >= ? AND date_format(obs_datetime, '%Y-%m-%d') <= ?",
                                            @start_date, @end_date],
                           :select => "person.voided,obs.value_coded,obs.obs_datetime,obs.voided ")
  
    @times = []                         
    @data_hash = Hash.new
    start_date = @start_date
    end_date = @end_date

    while start_date >= @start_date and start_date <= @end_date
      @times << start_date
      start_date = 1.weeks.from_now(start_date.monday)
      end_date = start_date-1.day
      #end_date = 4.days.from_now(start_date)
      if end_date >= @end_date
        end_date = @end_date
      end
    end
    
    @times.each{|t|
      @diagnoses_hash = {}
      patients = []
      @patient.each{|p|
        next_start_day = 1.weeks.from_now(t.monday)
        end_day = next_start_day - 1.day
        if end_day >= @end_date
          end_day = @end_date
        end
        patients << p if p.obs_datetime.to_date >= t and p.obs_datetime.to_date <= end_day
      }
      @diagnoses.each{|d|
        count = 0
        patients.each{|patient|
          count += 1  if patient.value_coded == d.value_coded
        }
        @diagnoses_hash[d.name] = count
      }
      @data_hash["#{t}"] = @diagnoses_hash
    }

    #Now create an array to use for sorting when we get to the view
    @sort_array = []
    sort_hash = {}

    @diagnoses.each{|d|
      sum = 0
      @times.each{|t|
        @data_hash.each{|time,data|
          if t.to_date == time.to_date 
            data.each{|k,v|
            if k == d.name
              sum = sum + v 
            end
          }
          end
      }


    }
    sort_hash[d.name] = sum

    }

  sort_hash = sort_hash.sort{|a,b| -1*( a[1]<=>b[1])}
   sort_hash.each{|x| @sort_array << x[0]}

  # make_and_send_pdf('/report/weekly_report', 'weekly_report.pdf')

  end

  def disaggregated_diagnosis

  @start_date = Date.new(params[:start_year].to_i,params[:start_month].to_i,params[:start_day].to_i) rescue nil
  @end_date = Date.new(params[:end_year].to_i,params[:end_month].to_i,params[:end_day].to_i) rescue nil
   if @start_date > @end_date
      flash[:notice] = 'Start date is greater that end date'
      redirect_to :action => 'select'
      return
    end

  #getting an array of all diagnoses recorded within the chosen period - to avoid including existent but non recorded diagnoses
  diagnoses = ConceptName.find(:all,
                                  :joins =>
                                        "INNER JOIN obs ON
                                         concept_name.concept_id = obs.value_coded AND obs.voided = 0",
                                  :conditions => ["date_format(obs_datetime, '%Y-%m-%d') >= ? AND date_format(obs_datetime, '%Y-%m-%d') <= ?",
                                            @start_date, @end_date],
                                  :group =>   "name",
                                  :select => "concept_name.concept_id,concept_name.name,obs.value_coded,obs.obs_datetime,obs.voided")
  #getting list of all patients who were diagnosed within the set period-to avoid getting all patients                          
  @patient = Person.find(:all,
                           :joins => 
                                "INNER JOIN obs ON 
                                 person.person_id = obs.person_id AND obs.voided = 0",
                           :conditions => ["date_format(obs_datetime, '%Y-%m-%d') >= ? AND date_format(obs_datetime, '%Y-%m-%d') <= ?",
                                            @start_date, @end_date],
                           :select => "person.gender,person.birthdate,person.birthdate_estimated,person.date_created,
                                      person.voided,obs.value_coded,obs.obs_datetime,obs.voided ")
  
  sort_hash = Hash.new

  #sorting the diagnoses using frequency with the highest first
  diagnoses.each{|diagnosis|
    count = 0
    @patient.each{|patient|
      if patient.value_coded == diagnosis.value_coded
        count += 1
      end
    }
    sort_hash[diagnosis.name] = count
  
  }
  #A sorted array of diagnoses to be sent to be sent to form
  @diagnoses = Array.new

   sort_hash = sort_hash.sort{|a,b| -1*( a[1]<=>b[1])}
   diagnosis_names = []
   sort_hash.each{|x| diagnosis_names << x[0]}
   diagnosis_names.each{|d|
     diagnoses.each{|diag|
       @diagnoses << diag if d == diag.name     
     }
   }
   

  end

  def referral
     @start_date = Date.new(params[:start_year].to_i,params[:start_month].to_i,params[:start_day].to_i) rescue nil
    @end_date = Date.new(params[:end_year].to_i,params[:end_month].to_i,params[:end_day].to_i) rescue nil
      if @start_date > @end_date
        flash[:notice] = 'Start date is greater that end date'
        redirect_to :action => 'select'
        return
      end

    @referrals = Observation.find(:all, :conditions => ["concept_id = ? AND date_format(obs_datetime, '%Y-%m-%d') >= ? AND 
                                  date_format(obs_datetime, '%Y-%m-%d') <= ?", 2227, @start_date, @end_date])
    @facilities = Observation.find(:all, :conditions => ["concept_id = ?", 2227], :group => "value_text")
  end

  def report_date_select
  end
  
  def select

    @report_date_range  = [""]
    @patient_type       = [""]
    @grouping           = [""]
    @outcome            = [""]

    @report_type        = params[:report_type]
    @query              = params[:query].gsub(" ", "_")

    start_date          = Encounter.initial_encounter.encounter_datetime
    end_date            = session[:datetime].to_date rescue Date.today

    report_date_ranges  = Report.generate_report_date_range(start_date, end_date)
    @date_range_values  = [["",""]]
    @report_date_range  = report_date_ranges.inject({}){|date_range, report_date_range|
                            date_range[report_date_range.first]         = report_date_range.last["datetime"]
                            @date_range_values.push([report_date_range.last["range"].first, report_date_range.first])
                            date_range
                          }

    case @report_type
      when "patient_analysis"
        case @query
          when "demographics"
            @patient_type       += ["Women", "Children", "All"]
            @grouping           += [["By Week", "week"], ["By Month", "month"]]

          when "health_issues"
            @patient_type       += ["Women", "Children"]
            @grouping           += [["By Week", "week"], ["By Month", "month"]]
            @health_task         = ["", "Health Symptoms", "Danger Warning Signs",
                                    "Health Information Requested", "Outcomes"]
          when "ages_distribution"
            @patient_type       += ["Women", "Children", "All"]
            @grouping           += [["By Week", "week"], ["By Month", "month"]]
          when "patient_activity"
            @patient_type       += ["Women", "Children", "All"]
            @grouping           += [["By Week", "week"], ["By Month", "month"]]
          when "referral_followup"
            @patient_type       += ["Women", "Children", "All"]
            @outcomes            = ["","REFERRED TO A HEALTH CENTRE",
                                    "REFERRED TO NEAREST VILLAGE CLINIC",
                                    "PATIENT TRIAGED TO NURSE SUPERVISOR",
                                    "GIVEN ADVICE NO REFERRAL NEEDED"]
            @grouping           += [["By Week", "week"], ["By Month", "month"]]
        end
      when "call_analysis"
        #case @query
          #when "call_time_of_day"
            @patient_type       += ["Women", "Children", "All"]
            @grouping           += [["By Week", "week"], ["By Month", "month"]]
            @staff               = [["",""]] + get_staff_members_list + [["All","All"]]
            @call_type           = ["","Normal", "Followup","Non-Patient Tips",
                                    "Emergency","Irrelevant",
                                    "All Patient Interaction",
                                    "All Non-Patient", "All"]
            @call_status         = ["","Yes","No", "All"]

      when "tips"
        @grouping           += [["",""],["By Week", "week"], ["By Month", "month"]]
        @content_type       = [["",""],["Pregnancy", "pregnancy"],["Child","child"]]
        @phone_type         = [["",""],["Community", "community"],["Personal","personal"],
                               ["Family","family"],["Neighbour","Neighbour"]]
        @language           = [["",""],["Yao","yao"],["Chichewa","chichewa"]]
        @delivery           = [["",""],["SMS","sms"],["Voice","voice"]]
        @network_prefix     = [["",""],["09","airtel"],["08","tnm"],["Other","other"]]

    end

     render :template => "/report/patient_analysis_selection" ,
              :layout => "application"
  end

  def select_remote_options
    render :layout => false
  end

  def remote_report
    s_day = params[:post]['start_date(3i)'].to_i #2
    s_month = params[:post]['start_date(2i)'].to_i #12
    s_year = params[:post]['start_date(1i)'].to_i  #2008
    e_day = params[:post]['end_date(3i)'].to_i #18
    e_month = params[:post]['end_date(2i)'].to_i #1
    e_year = params[:post]['end_date(1i)'].to_i # 2009
    parameters = {'start_year' => s_year, 'start_month' => s_month, 
                  'start_day' => s_day,'end_year' => e_year,
                  'end_month' => e_month, 'end_day' => e_day}

    if params[:report] == 'Weekly report'
      redirect_to :action => 'weekly_report', :params => parameters
    elsif params[:report] == 'Disaggregated Diagnoses'
      redirect_to :action => 'disaggregated_diagnosis', :params => parameters
    elsif params[:report] == 'Referrals'
      redirect_to :action => 'referral', :params => parameters
    end

  end

  def generate_pdf_report
    make_and_send_pdf('/report/weekly_report', 'weekly_report.pdf')
  end

  def mastercard
  end

  def type
    report_type = params[:q]
    case  report_type
      when 'patient_analysis'
        @reports = ["Demographics",     "Ages Distribution", "Health Issues",
                    "Patient Activity", "Referral Followup", "Call Feedback"]

        @report_label = 'a Patient Analysis Report'
        @report_type  = report_type

      when 'tips'
        @reports = ["Tips Activity", "Current Enrollment Totals",
                    "Individual Current Enrollments"]

        @report_label = 'a Tips Report'
        @report_type  = report_type

      when 'call_analysis'
        @reports = ["Call Time of Day", "Call Day Distribution",
                    "Call Lengths",     "Call Feedback"]

        @report_label = 'a Call Analysis Report'
        @report_type  = report_type
    end
    render :template => '/report/type', :layout => 'clinic'
  end

  def reports
    case  params[:query]
      when 'demographics'
        redirect_to :action       => "patient_demographics_report",
                  :start_date   => params[:start_date],
                  :end_date     => params[:end_date],
                  :grouping     => params[:grouping],
                  :patient_type => params[:patient_type],
                  :report_type  => params[:report_type],
                  :query        => params[:query]

      when 'health_issues'
        health_task = params[:health_task].downcase.gsub(" ", "_")
        redirect_to :action       => "patient_health_issues_report",
                  :start_date   => params[:start_date],
                  :end_date     => params[:end_date],
                  :grouping     => params[:grouping],
                  :patient_type => params[:patient_type],
                  :report_type  => params[:report_type],
                  :health_task  => health_task,
                  :query        => params[:query]

      when 'ages_distribution'
        redirect_to :action       => "patient_age_distribution_report",
                  :start_date   => params[:start_date],
                  :end_date     => params[:end_date],
                  :grouping     => params[:grouping],
                  :patient_type => params[:patient_type],
                  :report_type  => params[:report_type],
                  :query        => params[:query]
      when 'patient_activity'
        redirect_to :action       => "patient_activity_report",
                  :start_date   => params[:start_date],
                  :end_date     => params[:end_date],
                  :grouping     => params[:grouping],
                  :patient_type => params[:patient_type],
                  :report_type  => params[:report_type],
                  :query        => params[:query]
    when 'referral_followup'
        redirect_to :action       => "patient_referral_report",
                  :start_date   => params[:start_date],
                  :end_date     => params[:end_date],
                  :grouping     => params[:grouping],
                  :patient_type => params[:patient_type],
                  :report_type  => params[:report_type],
                  :query        => params[:query],
                  :outcome      => params[:outcome]

    when 'call_time_of_day'
        redirect_to :action       => "call_time_of_day",
                  :start_date   => params[:start_date],
                  :end_date     => params[:end_date],
                  :grouping     => params[:grouping],
                  :patient_type => params[:patient_type],
                  :report_type  => params[:report_type],
                  :query        => params[:query],
                  :call_type    => params[:call_type],
                  :call_status  => params[:call_status],
                  :staff_member => params[:staff_member]

    when 'call_day_distribution'
        redirect_to :action       => "call_day_distribution",
                  :start_date   => params[:start_date],
                  :end_date     => params[:end_date],
                  :grouping     => params[:grouping],
                  :patient_type => params[:patient_type],
                  :report_type  => params[:report_type],
                  :query        => params[:query],
                  :call_type    => params[:call_type],
                  :call_status  => params[:call_status],
                  :staff_member => params[:staff_member]

    when 'call_lengths'
        redirect_to :action       => "call_lengths",
                  :start_date   => params[:start_date],
                  :end_date     => params[:end_date],
                  :grouping     => params[:grouping],
                  :patient_type => params[:patient_type],
                  :report_type  => params[:report_type],
                  :query        => params[:query],
                  :call_type    => params[:call_type],
                  :call_status  => params[:call_status],
                  :staff_member => params[:staff_member]

    when 'tips_activity'
      redirect_to :action        => "tips_activity",
                :start_date    => params[:start_date],
                :end_date      => params[:end_date],
                :grouping      => params[:grouping],
                :content_type  => params[:content_type],
                :language      => params[:language],
                :query         => params[:query],
                :phone_type    => params[:phone_type],
                :delivery      => params[:delivery],
                :number_prefix => params[:number_prefix]

    end

  end

  def patient_demographics_report
    @start_date   = params[:start_date]
    @end_date     = params[:end_date]
    @patient_type = params[:patient_type]
    @report_type  = params[:report_type]
    @query        = params[:query]
    @grouping     = params[:grouping]

    @report_name  = "Patient Demographics"
    @report       = Report.patient_demographics(@patient_type, @grouping,
                                                @start_date, @end_date)
    render :layout => false
  end

  def patient_health_issues_report
    @start_date   = params[:start_date]
    @end_date     = params[:end_date]

    @patient_type = params[:patient_type]
    @report_type  = params[:report_type]
    @health_task  = params[:health_task]

    @query        = params[:query]
    @grouping     = params[:grouping]

    @report_name  = "Patient Health Issues"
    @report       = Report.patient_health_issues(@patient_type, @grouping, 
                                                  @health_task, @start_date,
                                                  @end_date)
    render :layout => false
  end

  def patient_age_distribution_report
    @start_date   = params[:start_date]
    @end_date     = params[:end_date]
    @patient_type = params[:patient_type]
    @report_type  = params[:report_type]
    @query        = params[:query]
    @grouping     = params[:grouping]

    case @patient_type.downcase
    when 'women'
      @special_message = "<I> -- (Please note that age is in <B> Years </B>) </I>"
    when 'children'
      @special_message = "<I> -- (Please note that age is in <B> Months </B>) </I>"
    else
      @special_message = "<I> -- (Please note that the Women age is in " +
                         "<B> Years </B> and that of Children is in " +
                         "<B> Months </B>)</I>"
    end


    @report_name  = "Patient Age Distribution"
    @report       = Report.patient_age_distribution(@patient_type, @grouping,
                                                    @start_date, @end_date)
    #raise @report.to_yaml
    render :layout => false
  end

  def patient_activity_report
    @start_date   = params[:start_date]
    @end_date     = params[:end_date]
    @patient_type = params[:patient_type]
    @report_type  = params[:report_type]
    @query        = params[:query]
    @grouping     = params[:grouping]
    @special_message = ""

    @report_name  = "Patient Activity"
    @report    = Report.patient_activity(@patient_type, @grouping,
                                         @start_date, @end_date)
    render :layout => false
  end

  def patient_referral_report
    @start_date   = params[:start_date]
    @end_date     = params[:end_date]
    @patient_type = params[:patient_type]
    @report_type  = params[:report_type]
    @query        = params[:query]
    @grouping     = params[:grouping]
    @outcome      = params[:outcome]
    @special_message = ""

    #raise params.to_yaml
    @report_name  = "Referral Followup"
    @report    = Report.patient_referral_followup(@patient_type, @grouping, @outcome,
                                         @start_date, @end_date)
   # raise @report.to_yaml
    render :layout => false
  end

  def get_staff_members_list
    staff = User.find(:all).map{|u| ["#{u.username}", "#{u.user_id}"]}

    return staff
  end
  def call_time_of_day
    @start_date   = params[:start_date]
    @end_date     = params[:end_date]
    @patient_type = params[:patient_type]
    @report_type  = params[:report_type]
    @query        = params[:query]
    @grouping     = params[:grouping]
    @staff_member = params[:staff_member]
    @call_status  = params[:call_status]
    @call_type    = params[:call_type]
    @special_message = ""

    if @staff_member == "All"
      @staff = @staff_member
    else
      @staff = User.find(@staff_member).username
    end

    #raise params.to_yaml
    @report_name  = "Call Time Of Day"
    @report    = Report.call_time_of_day(@patient_type, @grouping, @call_type,
                                         @call_status, @staff_member,
                                         @start_date, @end_date)
    #raise @report.to_yaml
    render :layout => false
  end

  def call_day_distribution
    @start_date   = params[:start_date]
    @end_date     = params[:end_date]
    @patient_type = params[:patient_type]
    @report_type  = params[:report_type]
    @query        = params[:query]
    @grouping     = params[:grouping]
    @staff_member = params[:staff_member]
    @call_status  = params[:call_status]
    @call_type    = params[:call_type]
    @special_message = ""

    if @staff_member == "All"
      @staff = @staff_member
    else
      @staff = User.find(@staff_member).username
    end
    
    #raise params.to_yaml
    @report_name  = "Call Day Distribution"
    @report    = Report.call_day_distribution(@patient_type, @grouping, @call_type,
                                         @call_status, @staff_member,
                                         @start_date, @end_date)
    #raise @report.to_yaml
    render :layout => false
  end

  def call_lengths
    @start_date   = params[:start_date]
    @end_date     = params[:end_date]
    @patient_type = params[:patient_type]
    @report_type  = params[:report_type]
    @query        = params[:query]
    @grouping     = params[:grouping]
    @staff_member = params[:staff_member]
    @call_status  = params[:call_status]
    @call_type    = params[:call_type]
    @special_message = "<I> -- (Please note that the call lengths " +
                       "are in <B>Seconds</B>)<I>"

    if @staff_member == "All"
      @staff = @staff_member
    else
      @staff = User.find(@staff_member).username
    end

    @report_name  = "Call Length"
    @report    = Report.call_lengths(@patient_type, @grouping, @call_type,
                                         @call_status, @staff_member,
                                         @start_date, @end_date)
    render :layout => false
  end

  def tips_activity
    @start_date     =  params[:start_date]
    @end_date       = params[:end_date]
    @grouping       = params[:grouping]
    @content_type   = params[:content_type]
    @language       = params[:language]
    @query          = params[:query]
    @phone_type     = params[:phone_type]
    @delivery       = params[:delivery]
    @number_prefix  = params[:number_prefix]

    @special_message = "<I> -- (Please note that the call lengths " +
                       "are in <B>Seconds</B>)<I>"

    @report_name  = "Call Length"
    @report    = Report.tips_activity(@start_date, @end_date, @grouping,
                                      @content_type, @language, @phone_type,
                                      @delivery, @number_prefix)
    render :layout => false
  end
end
