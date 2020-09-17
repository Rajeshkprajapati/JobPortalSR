using System;
using System.Collections.Generic;
using System.Text;
using JobPortal.Model.DataViewModel.Employer.AdvanceSearch;
using JobPortal.Model.DataViewModel.Employer.SearchResume;
using JobPortal.Model.DataViewModel.Shared;

namespace JobPortal.Business.Interfaces.Employer.SearchResume
{
    public interface ISearchResumeHandler
    {
        List<SearchResumeListViewModel> GetSearchResumeList(SearchResumeViewModel searches);
        void LogSearchResumeList(SearchResumeViewModel searches,string userip,int empid);
        SearchResumeListViewModel ShowCandidateDetails(int employerId, int jobSeekerId);
        List<CityViewModel> GetCityList();
        List<GenderViewModel> GetGenders();
        IList<UserViewModel> GetEmployers(bool isAll);
        List<SearchResumeListViewModel> GetAdvanceSearchResumeList(AdvanceResumeSearch searches,int userId);
        List<AdvanceResumeSearch> AdvanceSearchStates(int UserId);
        List<AdvanceResumeSearch> AdvanceSearchById(int Id, int UserId);
    }
}
