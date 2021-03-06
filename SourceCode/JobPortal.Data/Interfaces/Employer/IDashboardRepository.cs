﻿using JobPortal.Data.DataModel.Employer.JobPost;
using JobPortal.Data.DataModel.Shared;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.Employer
{
    public interface IDashboardRepository
    {
        DataTable GetProfileData(int empId);
        DataTable GetJobs(int empId, int year, int jobId = 0,bool isDraftJob=false);
        DataTable GetJobSeekers(int empId, int jobId=0);
        DataSet GetDashboard(int empId);
        DataTable GetViewedProfiles(int empId);
        DataTable GetJobSeekersBasedOnEmployerHiringCriteria(int empId, string year, string city, string role);
        DataTable GetJob(int jobId);
        bool UpdateJob(int userId, int jobId, JobPostModel job);
        DataTable GetMessages(DateTime msgsOnDate, int empId);
        bool UpdateJobSeekerMailStatus(int messageId,int userId);
        //DataTable GetJobSeekersByCity(string cityCode);
        //DataTable GetJobSeekersByYear(string year);
        DataTable GetActiveCloseJobs(int empId, int year, int JobStatus);
        bool DactiveActiveJobs(string id, int JobPostId);
        DataTable BulkResumeData(string UserIds);
        bool SaveProfileHistory(int UserId, string JobSeekerIds, string FileUrl);
        DataTable EmployerRecentJobPost(int empId);
    }
}
