using JobPortal.Model.DataViewModel.JobSeeker;
using JobPortal.Model.DataViewModel.Shared;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Business.Interfaces.Jobseeker
{
    public interface IResumeBuilderHandler
    {
        //void CreateResume(int userId);
        void CreateResume(int userId, string htmlContent);
        IEnumerable<StateViewModel> GetStates(string cCode);
        IEnumerable<CityViewModel> GetCities(string sCode);
        dynamic GetUserDetails(int userId);
        bool InsertExperienceDetails(int userId,ExperienceDetails[] exp,Skills skills);
        bool InsertEducationDetails(int userId, EducationalDetails[] educations);
        bool InsertPersonalDetails(int userId, UserViewModel user);
        string GetResume(int userId);
        IEnumerable<CourseViewModel> GetCourses(int cCategory);
        ResumeViewModel GetUserInfoToCreateResume(int userId);
    }
}
