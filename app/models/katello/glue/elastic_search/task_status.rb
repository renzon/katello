module Katello
  module Glue::ElasticSearch::TaskStatus
    def self.included(base)
      base.send :include, Ext::IndexedModel

      base.class_eval do
        index_options :json => { :only => [:parameters, :organization_id, :start_time,
                                           :finish_time, :task_owner_id, :task_owner_type] },
                      :extended_json => :extended_index_attrs

        mapping do
          indexes :start_time, :type => 'date'
          indexes :finish_time, :type => 'date'
          indexes :status, :type => 'string', :analyzer => 'snowball'
          indexes :task_owner_type, :type => 'string', :index => :not_analyzed
          indexes :message, :type => 'string', :analyzer => 'snowball'
          indexes :result, :type => 'string', :analyzer => 'snowball'
        end
      end
    end

    def extended_index_attrs
      ret = {}
      ret[:result] = self.result.to_s
      ret[:message] = self.message
      ret[:login] = user.login if user
      ret[:status] = state.to_s
      ret[:status] += " pending" if pending?
      ret[:start_time] = self.start_time || self.created_at

      if state.to_s == "error" || state.to_s == "timed_out"
        ret[:status] += " fail failure"
      end

      case state.to_s
      when "finished"
        ret[:status] += " completed"
      when "timed_out"
        ret[:status] += " timed out"
      end

      if task_type
        tt = task_type
        if (System.class.name == task_owner_type)
          tt = TaskStatus::TYPES[task_type][:english_name]
        end
        ret[:status] += " #{tt}"
      end
      ret
    end
  end
end
