using JobPortal.Data.DataModel.Employer.JobPost;
using JobPortal.Model.DataViewModel.Employer.JobPost;
using JobPortal.Model.DataViewModel.JobSeeker;
using JobPortal.Model.DataViewModel.Shared;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Business.Interfaces.Employer.JobPost
{
    public interface IJobPostHandler
    {
        List<JobTitleViewModel> GetJobTitleDetails();
        List<JobIndustryAreaModel> GetJobIndustryAreaWithStudentData();
        List<JobIndustryAreaModel> GetJobIndustryAreaWithJobPost();
        List<JobIndustryAreaModel> GetJobIndustryAreaDetails();
        List<EmploymentStatusModel> GetJobJobEmploymentStatusDetails();
        List<EmploymentTypeModel> GetJobJobEmploTypeDetails();
        List<CountryViewModel> GetCountryDetails();
        List<CourseViewModel> GetCourseCategory();
        List<CourseViewModel> GetCourses(int Categoryid);
        List<StateViewModel> GetStateList(string CountryCode);
        List<CityViewModel> GetCityList(string StateCode);
        List<GenderViewModel> GetGenderListDetail();
        bool AddJobPost(JobPostViewModel model, int userId,bool isDraftJob=false);
        JobPostViewModel GetJobDetails(int jobid);
        bool AddPreferredLocation(string[] location,int userid);
        List<JobTypeViewModel> GetJobTypes();
        List<SearchJobListViewModel> RecommendedJobs(int roleid);
    }
}
