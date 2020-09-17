using JobPortal.Data.DataModel.Shared;
using JobPortal.Model.DataViewModel.Employer.AdvanceSearch;
using JobPortal.Model.DataViewModel.Shared;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.Employer.SearchResume
{
    public interface ISearchResumeRepository
    {
        DataTable GetSearchResumeList(SearchResumeModel searches);
        DataTable ShowCandidateDetails(int employerId, int jobSeekerId);
        void LogSearchResumeList(string searches,string userip,string location,int empid);
        DataTable GetAdvanceSearchResumeList(AdvanceResumeSearch searches, int userId);
        DataTable AdvanceSearchStates(int userId);
        DataTable AdvanceSearchById(int Id, int userId);
    }
}

