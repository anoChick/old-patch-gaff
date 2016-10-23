# frozen_string_literal: true
require 'sinatra'
require 'json'
require 'google_drive'
require 'yaml'

CONF = nil
begin
  CONF = YAML.load_file('config.yml')
rescue
  raise('Config file not found.') unless CONF
end

class SpreadSheet
  LIMIT_ROW_COUNT = 100_000
  attr_accessor :session, :ws
  def initialize
    @session = GoogleDrive::Session.from_service_account_key(CONF['google']['service_account']['json_key_path'])
  end

  def append_close_pr(user_name, issue_no, title, datetime, url)
    # closeしたPRの数(Ownerのカウント)
    @ws = session.spreadsheet_by_key(CONF['google']['spread_sheet']['data_source_sheet_id']).worksheets[0]
    row_index = seek_end_row_index
    @ws[row_index, 1] = user_name
    @ws[row_index, 2] = issue_no
    @ws[row_index, 3] = title
    @ws[row_index, 4] = datetime
    @ws[row_index, 5] = url
    @ws.save
  end

  def append_close_issue(user_name, issue_no, title, datetime, url)
    # #closeしたissueの数(Assigneeのカウント)
    @ws = session.spreadsheet_by_key(CONF['google']['spread_sheet']['data_source_sheet_id']).worksheets[1]
    row_index = seek_end_row_index
    @ws[row_index, 1] = user_name
    @ws[row_index, 2] = issue_no
    @ws[row_index, 3] = title
    @ws[row_index, 4] = datetime
    @ws[row_index, 5] = url
    @ws.save
  end

  private

  def seek_end_row_index
    return nil if ws.nil?
    1.upto(LIMIT_ROW_COUNT) { |index| return index if ws[index, 1] == '' }

    nil
  end
end

set :bind, '0.0.0.0'
post '/github' do
  payload = params[:payload] ? JSON.parse(params[:payload]) : nil
  status 403 && return if payload.nil?
  if payload['action'] == 'closed'
    unless payload['pull_request'].nil?
      ss = SpreadSheet.new
      ss.append_close_pr(
        payload['pull_request']['user']['login'],
        payload['pull_request']['number'],
        payload['pull_request']['title'],
        Date.today.strftime,
        payload['pull_request']['url']
      )
      return
    end
    unless payload['issue'].nil?
      payload['issue']['assignees'].each do |assignee|
        ss = SpreadSheet.new
        ss.append_close_issue(
          assignee['login'],
          payload['issue']['number'],
          payload['issue']['title'],
          Date.today.strftime,
          payload['issue']['url']
        )
      end
      return
    end

  end
end
