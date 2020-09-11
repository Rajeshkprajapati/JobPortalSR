using System;
using System.Collections.Generic;
using System.Text;
using JobPortal.Model.DataViewModel.Employer.SearchResume;
using JobPortal.Model.DataViewModel.Shared;

namespace JobPortal.Business.Interfaces.Employer.SearchResume
{
    public interface ISearchResumeHandler
    {
        List<SearchResumeListViewModel> GetSearchResumeList(SearchResumeViewModel searches);
        void LogSearchResumeList(SearchResumeViewModel searches,string userip,int empid);
        SearchResumeListViewModel ShowCandidateDetails(int employerId, int jobSeekerId);
    }
}
