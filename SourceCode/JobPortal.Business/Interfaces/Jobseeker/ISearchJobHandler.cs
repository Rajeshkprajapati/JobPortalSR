using JobPortal.Model.DataViewModel.JobSeeker;
using JobPortal.Model.DataViewModel.Shared;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Business.Interfaces.Jobseeker
{
    public interface ISearchJobHandler
    {
        List<SearchJobListViewModel> SearchJobList(SearchJobViewModel searches, int UserId);
        void LogSearchJob(SearchJobViewModel searches,string userip, int UserId);
    }
}
