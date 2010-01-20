# redMine - project management software
# Copyright (C) 2006-2008  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require "#{File.dirname(__FILE__)}/../test_helper"

class IssuesTest < ActionController::IntegrationTest
  fixtures :projects,
           :users,
           :roles,
           :members,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :issue_statuses,
           :issues,
           :enumerations,
           :custom_fields,
           :custom_values,
           :custom_fields_trackers

  # when create a new issue, after setting "Assigned to", and the Status is "New", then the status should be setted to "Assigned"
  def test_add_issue
    log_user('jsmith', 'jsmith')
    get 'projects/1/issues/new', :tracker_id => '1'
    assert_response :success
    assert_template 'issues/new'

    post 'projects/1/issues', :tracker_id => "1",
                                 :issue => { :start_date => "2006-12-26",
                                             :priority_id => "4",
                                             :subject => "new test issue",
                                             :category_id => "",
                                             :description => "new issue",
                                             :done_ratio => "0",
                                             :due_date => "",
                                             :assigned_to_id => session[:user_id] },
                                 :custom_fields => {'2' => 'Value for field 2'}
    # find created issue
    issue = Issue.find_by_subject("new test issue")
    assert_kind_of Issue, issue

    # check redirection
    assert_redirected_to :controller => 'issues', :action => 'show', :id => issue
    follow_redirect!
    assert_equal issue, assigns(:issue)

    # check issue attributes
    assert_equal 'jsmith', issue.author.login
    assert_equal 1, issue.project.id
    assert_equal 'jsmith', issue.assigned_to.login
    assert_equal 2, issue.status.id
  end

  def test_auto_set_done_ratio_when_resolved
    log_user('jsmith', 'jsmith')

    post 'issues/1/edit',
            :issue => {
              :status_id => IssueStatus.find_by_name('Resolved').id,
              :done_ratio => "0"
            }
       
    assert_redirected_to "issues/1"

    assert_equal "Resolved", Issue.find(1).status.name
    assert_equal 100, Issue.find(1).done_ratio
  end

end
