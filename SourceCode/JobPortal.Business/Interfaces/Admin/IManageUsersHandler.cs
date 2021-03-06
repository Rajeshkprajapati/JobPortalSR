﻿using JobPortal.Model.DataViewModel.Admin.ManageUsers;
using JobPortal.Model.DataViewModel.Admin.Notifications;
using JobPortal.Model.DataViewModel.Employer.JobPost;
using JobPortal.Model.DataViewModel.JobSeeker;
using JobPortal.Model.DataViewModel.Shared;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Business.Interfaces.Admin
{
    public interface IManageUsersHandler
    {
        List<ManageUsersViewModel> GetAllUsers(int userId);
        List<AppliedJobsViewModel> GetAppliedJobsInRange(string startDate, string endDate);
        List<ManageUsersViewModel> GetAllUserRegistrations(string registrationType, string sDate, string eDate);
        List<JobPostViewModel> GetJobsInDateRange(string startDay, string endDay);
        List<AppliedJobsViewModel> MonthlyAppliedJobs(int month, int year, string gender, string state);
        IList<UserViewModel> MonthlyRegisteredUsers(int month, int year,string state,string gender);
        DataSet DashboardTilesRecordCount(string date,string endDate);
        DataSet GetGraphData(int year, string gender, string state);
        IList<JobPostViewModel> MonthlyJobs(int month, int year, string state, bool activeJobs);
        bool DeleteUsersById(string userid);

        bool UpdateUsersData(ManageUsersViewModel user);

        bool ApproveUser(ManageUsersViewModel user);
        List<JobPostViewModel> JobPostMonthlyStateWiseRecord(string month, string year, string state);
        List<StateViewModel> GetStates(string country);
        List<GenderViewModel> GetGenders();
        List<JobPostViewModel> GetBulkJobSearchList(int CompanyId, string FY, string statecode, string citycode);
        bool DeleteBulkJobs(string JobPostId);
        IEnumerable<JobPostViewModel> GetJobs(int empId, int year,int JobId);
        IEnumerable<EmailTemplateViewModel> GetEmailTemplate(int UserRole,int Id);
    }
}
